.text
.globl _start
_start:
	xorl	%r9d, %r9d		# exit status = 0
	cmpq	$2, (%rsp)
	jne	.Lusage

	# sys_open(argv[1], O_RDWR | O_CLOEXEC, 0)
	movq	16(%rsp), %rdi
	movl	$0x80002, %esi
	xorl	%edx, %edx
	movl	$2, %eax		# __NR_open
	syscall

	testl	%eax, %eax
	js	.Lerr_open

	movl	%eax, %r8d		# r8d = fd

	# Setup payload and struct uvc_xu_control_query on stack
	subq	$32, %rsp
	movq	$0x0000000000020301, (%rsp)
	movb	$0, 8(%rsp)
	movl	$0x0001060e, 16(%rsp)	# unit=14, sel=6, query=1
	movl	$9, 20(%rsp)		# size=9
	movq	%rsp, 24(%rsp)		# data = &payload

	# sys_ioctl(fd, UVCIOC_CTRL_QUERY, &query)
	movl	%r8d, %edi
	movl	$0xc0107521, %esi
	leaq	16(%rsp), %rdx
	movl	$16, %eax		# __NR_ioctl
	syscall

	testl	%eax, %eax
	jns	.Lclose

	leaq	str_ioctl(%rip), %rsi
	movl	$str_ioctl_len, %edx
	call	.Lwarn

.Lclose:
	# sys_close(fd)
	movl	%r8d, %edi
	movl	$3, %eax		# __NR_close
	syscall

	testl	%eax, %eax
	jns	.Lexit

	leaq	str_close(%rip), %rsi
	movl	$str_close_len, %edx
	call	.Lwarn

.Lexit:
	movl	%r9d, %edi
	movl	$60, %eax		# __NR_exit
	syscall

.Lusage:
	leaq	usage(%rip), %rsi
	movl	$usage_len, %edx
	jmp	.Ldie

.Lerr_open:
	leaq	str_open(%rip), %rsi
	movl	$str_open_len, %edx

.Ldie:
	call	.Lwarn
	jmp	.Lexit

.Lwarn:
	movl	$2, %edi		# stderr
	movl	$1, %eax		# __NR_write
	syscall
	movl	$1, %r9d
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
