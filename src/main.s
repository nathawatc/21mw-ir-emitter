# Sizes are minimized: registers are chosen for short encodings, and
# pushq/popq loads constants in 3 bytes where movl takes 5.
.text
.globl _start
_start:
	popq	%rax			# argc
	popq	%rdi			# argv[0]
	popq	%rdi			# argv[1]
	xorl	%ebp, %ebp		# exit status = 0
	cmpl	$2, %eax
	jne	.Lusage

	# sys_open(argv[1], O_RDWR | O_CLOEXEC): eax is already 2, __NR_open
	movl	$0x80002, %esi
	syscall

	testl	%eax, %eax
	js	.Lerr_open

	xchgl	%eax, %edi		# edi = fd, preserved across syscalls

	# Payload (9 bytes) followed by struct uvc_xu_control_query on stack
	pushq	$0
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

	testl	%eax, %eax
	jns	.Lclose

	movl	$str_ioctl, %esi
	pushq	$str_ioctl_len
	popq	%rdx
	call	.Lwarn

.Lclose:
	# sys_close(fd)
	pushq	$3			# __NR_close
	popq	%rax
	syscall

	testl	%eax, %eax
	jns	.Lexit

	movl	$str_close, %esi
	pushq	$str_close_len
	popq	%rdx
	call	.Lwarn

.Lexit:
	movl	%ebp, %edi
	pushq	$60			# __NR_exit
	popq	%rax
	syscall

.Lusage:
	movl	$usage, %esi
	pushq	$usage_len
	jmp	.Ldie

.Lerr_open:
	movl	$str_open, %esi
	pushq	$str_open_len

.Ldie:
	popq	%rdx
	call	.Lwarn
	jmp	.Lexit

	# sys_write(stderr, rsi, rdx), set exit status 1, preserve edi
.Lwarn:
	pushq	%rdi
	pushq	$2			# stderr
	popq	%rdi
	pushq	$1			# __NR_write
	popq	%rax
	syscall
	pushq	$1
	popq	%rbp
	popq	%rdi
	ret

.section .rodata
usage:
	.ascii	"usage: 21mw-ir-emitter DEVICE\n"
.set usage_len, . - usage
str_open:
	.ascii	"21mw-ir-emitter: open failed\n"
.set str_open_len, . - str_open
str_ioctl:
	.ascii	"21mw-ir-emitter: UVCIOC_CTRL_QUERY failed\n"
.set str_ioctl_len, . - str_ioctl
str_close:
	.ascii	"21mw-ir-emitter: close failed\n"
.set str_close_len, . - str_close
.section .note.GNU-stack,"",@progbits
