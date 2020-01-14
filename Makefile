

# Make variables (CC, etc...)

AS		= $(CROSS_COMPILE)as
# Always use GNU ld
ifneq ($(shell $(CROSS_COMPILE)ld.bfd -v 2> /dev/null),)
LD		= $(CROSS_COMPILE)ld.bfd
else
LD		= $(CROSS_COMPILE)ld
endif
CC		= $(CROSS_COMPILE)gcc
CPP		= $(CC) -E
AR		= $(CROSS_COMPILE)ar
NM		= $(CROSS_COMPILE)nm
LDR		= $(CROSS_COMPILE)ldr
STRIP		= $(CROSS_COMPILE)strip
OBJCOPY		= $(CROSS_COMPILE)objcopy
OBJDUMP		= $(CROSS_COMPILE)objdump
LEX		= flex
YACC		= bison
AWK		= awk
PERL		= perl
PYTHON		?= python
PYTHON2		= python2
PYTHON3		= python3
DTC		?= $(objtree)/scripts/dtc/dtc
CHECK		= sparse

CHECKFLAGS     := -D__linux__ -Dlinux -D__STDC__ -Dunix -D__unix__ \
		  -Wbitwise -Wno-return-void -D__CHECK_ENDIAN__ $(CF)

KBUILD_CPPFLAGS := -D__KERNEL__ -D__UBOOT__

KBUILD_CFLAGS   := -Wall -Wstrict-prototypes \
		   -Wno-format-security \
		   -fno-builtin -ffreestanding $(CSTD_FLAG)
KBUILD_CFLAGS	+= -fshort-wchar -fno-strict-aliasing
KBUILD_AFLAGS   := -D__ASSEMBLY__

# Don't generate position independent code
KBUILD_CFLAGS	+= $(call cc-option,-fno-PIE)
KBUILD_AFLAGS	+= $(call cc-option,-fno-PIE)

# Read UBOOTRELEASE from include/config/uboot.release (if it exists)
UBOOTRELEASE = $(shell cat include/config/uboot.release 2> /dev/null)
UBOOTVERSION = $(VERSION)$(if $(PATCHLEVEL),.$(PATCHLEVEL)$(if $(SUBLEVEL),.$(SUBLEVEL)))$(EXTRAVERSION)

export VERSION PATCHLEVEL SUBLEVEL UBOOTRELEASE UBOOTVERSION
export ARCH CPU BOARD VENDOR SOC CPUDIR BOARDDIR
export CONFIG_SHELL HOSTCC HOSTCFLAGS HOSTLDFLAGS CROSS_COMPILE AS LD CC
export CPP AR NM LDR STRIP OBJCOPY OBJDUMP
export MAKE LEX YACC AWK PERL PYTHON PYTHON2 PYTHON3
export HOSTCXX HOSTCXXFLAGS CHECK CHECKFLAGS DTC DTC_FLAGS

export KBUILD_CPPFLAGS NOSTDINC_FLAGS UBOOTINCLUDE OBJCOPYFLAGS LDFLAGS
export KBUILD_CFLAGS KBUILD_AFLAGS

ALL-$(CONFIG_SPL) += spl/u-boot-spl.bin

spl/u-boot-spl.srec: spl/u-boot-spl FORCE
	$(call if_changed,objcopy)

spl/u-boot-spl.hex: spl/u-boot-spl FORCE
	$(call if_changed,objcopy)

u-boot-spl.kwb: u-boot.img spl/u-boot-spl.bin FORCE
	$(call if_changed,mkimage)

ifeq ($(CONFIG_ARCH_ROCKCHIP),y)
MKIMAGEFLAGS_u-boot-tpl.img = -n $(CONFIG_SYS_SOC) -T rksd
tpl/u-boot-tpl.img: tpl/u-boot-tpl.bin FORCE
	$(call if_changed,mkimage)
idbloader.img: tpl/u-boot-tpl.img spl/u-boot-spl.bin FORCE
	$(call if_changed,cat)
endif


ifeq ($(CONFIG_ARCH_LPC32XX)$(CONFIG_SPL),yy)
MKIMAGEFLAGS_lpc32xx-spl.img = -T lpc32xximage -a $(CONFIG_SPL_TEXT_BASE)

lpc32xx-spl.img: spl/u-boot-spl.bin FORCE
	$(call if_changed,mkimage)

OBJCOPYFLAGS_lpc32xx-boot-0.bin = -I binary -O binary --pad-to=$(CONFIG_SPL_PAD_TO)

lpc32xx-boot-0.bin: lpc32xx-spl.img FORCE
	$(call if_changed,objcopy)

OBJCOPYFLAGS_lpc32xx-boot-1.bin = -I binary -O binary --pad-to=$(CONFIG_SPL_PAD_TO)

lpc32xx-boot-1.bin: lpc32xx-spl.img FORCE
	$(call if_changed,objcopy)

lpc32xx-full.bin: lpc32xx-boot-0.bin lpc32xx-boot-1.bin u-boot.img FORCE
	$(call if_changed,cat)

endif



SPL: spl/u-boot-spl.bin FORCE
	$(Q)$(MAKE) $(build)=arch/arm/mach-imx $@


ifeq ($(CONFIG_ARCH_IMX8M)$(CONFIG_ARCH_IMX8), y)
ifeq ($(CONFIG_SPL_LOAD_IMX_CONTAINER), y)
u-boot.cnt: u-boot.bin FORCE
	$(Q)$(MAKE) $(build)=arch/arm/mach-imx $@

flash.bin: spl/u-boot-spl.bin u-boot.cnt FORCE
	$(Q)$(MAKE) $(build)=arch/arm/mach-imx $@
else
flash.bin: spl/u-boot-spl.bin u-boot.itb FORCE
	$(Q)$(MAKE) $(build)=arch/arm/mach-imx $@
endif
endif

spl/u-boot-spl.ais: spl/u-boot-spl.bin FORCE
	$(call if_changed,mkimage)

OBJCOPYFLAGS_u-boot.ais = -I binary -O binary --pad-to=$(CONFIG_SPL_PAD_TO)
u-boot.ais: spl/u-boot-spl.ais u-boot.img FORCE
	$(call if_changed,pad_cat)

u-boot-signed.sb: u-boot.bin spl/u-boot-spl.bin
	$(Q)$(MAKE) $(build)=arch/arm/cpu/arm926ejs/mxs u-boot-signed.sb
u-boot.sb: u-boot.bin spl/u-boot-spl.bin
	$(Q)$(MAKE) $(build)=arch/arm/cpu/arm926ejs/mxs u-boot.sb

spl/u-boot-spl.img: spl/u-boot-spl.bin FORCE
	$(call if_changed,mkimage)

u-boot.spr: spl/u-boot-spl.img u-boot.img FORCE
	$(call if_changed,pad_cat)

ifeq ($(CONFIG_MPC85xx)$(CONFIG_OF_SEPARATE),yy)
u-boot-with-dtb.bin: u-boot.bin u-boot.dtb \
	$(if $(CONFIG_MPC85XX_HAVE_RESET_VECTOR), u-boot-br.bin) FORCE
	$(call if_changed,binman)

ifeq ($(CONFIG_MPC85XX_HAVE_RESET_VECTOR),y)
OBJCOPYFLAGS_u-boot-br.bin := -O binary -j .bootpg -j .resetvec
u-boot-br.bin: u-boot FORCE
	$(call if_changed,objcopy)
endif
endif

ifneq ($(CONFIG_X86_RESET_VECTOR),)
rom: u-boot.rom FORCE

refcode.bin: $(srctree)/board/$(BOARDDIR)/refcode.bin FORCE
	$(call if_changed,copy)

quiet_cmd_ldr = LD      $@
cmd_ldr = $(LD) $(LDFLAGS_$(@F)) \
	       $(filter-out FORCE,$^) -o $@

u-boot.rom: u-boot-x86-start16.bin u-boot-x86-reset16.bin u-boot.bin \
		$(if $(CONFIG_SPL_X86_16BIT_INIT),spl/u-boot-spl.bin) \
		$(if $(CONFIG_TPL_X86_16BIT_INIT),tpl/u-boot-tpl.bin) \
		$(if $(CONFIG_HAVE_REFCODE),refcode.bin) FORCE
	$(call if_changed,binman)

OBJCOPYFLAGS_u-boot-x86-start16.bin := -O binary -j .start16
u-boot-x86-start16.bin: u-boot FORCE
	$(call if_changed,objcopy)

OBJCOPYFLAGS_u-boot-x86-reset16.bin := -O binary -j .resetvec
u-boot-x86-reset16.bin: u-boot FORCE
	$(call if_changed,objcopy)
endif


OBJCOPYFLAGS_u-boot-nodtb-tegra.bin = -O binary --pad-to=$(CONFIG_SYS_TEXT_BASE)
u-boot-nodtb-tegra.bin: spl/u-boot-spl u-boot-nodtb.bin FORCE
	$(call if_changed,pad_cat)

OBJCOPYFLAGS_u-boot-tegra.bin = -O binary --pad-to=$(CONFIG_SYS_TEXT_BASE)
u-boot-tegra.bin: spl/u-boot-spl u-boot.bin FORCE
	$(call if_changed,pad_cat)

u-boot-img.bin: spl/u-boot-spl.bin u-boot.img FORCE
	$(call if_changed,cat)

spl/u-boot-spl.pbl: spl/u-boot-spl.bin FORCE
	$(call if_changed,mkimage)

u-boot-with-spl-pbl.bin: spl/u-boot-spl.pbl $(UBOOT_BINLOAD) FORCE
	$(call if_changed,pad_cat)


OBJCOPYFLAGS_u-boot-img-spl-at-end.bin := -I binary -O binary \
	--pad-to=$(CONFIG_UBOOT_PAD_TO) --gap-fill=0xff
u-boot-img-spl-at-end.bin: u-boot.img spl/u-boot-spl.bin FORCE
	$(call if_changed,pad_cat)

spl/u-boot-spl.bin: spl/u-boot-spl
	@:
	$(SPL_SIZE_CHECK)

export build := -f scripts/Makefile.build obj


spl/u-boot-spl: 
	$(Q)$(MAKE) obj=spl -f scripts/Makefile.spl all

spl/sunxi-spl.bin: spl/u-boot-spl
	@:



spl/u-boot-spl.sfp: spl/u-boot-spl
	@:

spl/boot.bin: spl/u-boot-spl
	@:


