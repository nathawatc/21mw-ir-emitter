# Sizes are minimized: registers are chosen for short encodings, and
# pushq/popq loads constants in 3 bytes where movl takes 5.
.text
.globl _start
_start:
	popq	%rax			# argc
	popq	%rdi			# argv[0]
	popq	%rdi			# argv[1]
	cmpl	$2, %eax
	jne	.Lusage

	# sys_open(argv[1], O_RDWR): eax is 2, both __NR_open and O_RDWR
	movl	%eax, %esi
	syscall

	testl	%eax, %eax
	js	.Lerr_open

	xchgl	%eax, %edi		# edi = fd, preserved across syscalls

	# Payload (9 bytes) followed by struct uvc_xu_control_query on stack.
	# The ninth byte, 0, is the argv[2] NULL now on top of the stack.
	pushq	$0x00020301
	pushq	%rsp			# data = &payload
	pushq	$0x0001060e		# unit=14, sel=6, query=1
	movb	$9, 4(%rsp)		# size=9

	# sys_ioctl(fd, UVCIOC_CTRL_QUERY, &query)
	movl	$0xc0107521, %esi
	pushq	%rsp
	popq	%rdx
	pushq	$16			# __NR_ioctl
	popq	%rax
	syscall
	xchgl	%eax, %ebp		# ebp = ioctl result, reported after close

	# sys_close(fd)
	pushq	$3			# __NR_close
	popq	%rax
	syscall

	# If both failed, only the ioctl error is reported: a deliberate trade-off
	# for size. The exit status is 1 either way.
	testl	%ebp, %ebp
	js	.Lerr_ioctl
	testl	%eax, %eax
	js	.Lerr_close
	xchgl	%eax, %edi		# exit status = 0

.Lexit:
	pushq	$60			# __NR_exit
	popq	%rax
	syscall

	# The stack holds one iovec: the rest of the message. Put the name first.
.Lprefix:
	pushq	$17			# length of .Lname
	pushq	$.Lname
	pushq	$2			# iovcnt
	popq	%rdx

	# sys_writev(stderr, iov, iovcnt), then exit with status 1
.Lwritev:
	pushq	%rsp
	popq	%rsi
	pushq	$2			# stderr
	popq	%rdi
	pushq	$20			# __NR_writev
	popq	%rax
	syscall
	decl	%edi			# exit status = 1
	jmp	.Lexit

	# Build a struct iovec on the stack: push the length, then let call push
	# the address of the text after it. Nothing returns. The push is spelled
	# in bytes because gas picks the 5-byte form for a forward reference.
.macro iovec target, text
	.byte	0x6a, 2f - 1f		# pushq $length
	call	\target
1:	.ascii	"\text"
2:
.endm

.Lusage:
	pushq	$1			# iovcnt
	popq	%rdx
	iovec	.Lwritev, "usage: 21mw-ir-emitter DEVICE\n"
.Lerr_open:
	iovec	.Lprefix, "open failed\n"
.Lerr_ioctl:
	iovec	.Lprefix, "UVCIOC_CTRL_QUERY failed\n"
.Lerr_close:
	iovec	.Lprefix, "close failed\n"

.Lname:
	.ascii	"21mw-ir-emitter: "
