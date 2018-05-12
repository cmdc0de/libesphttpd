#
# Component Makefile (for esp-idf)
#
# This Makefile should, at the very least, just include $(SDK_PATH)/make/component.mk. By default, 
# this will take the sources in this directory, compile them and link them into 
# lib(subdirectory_name).a in the build directory. This behaviour is entirely configurable,
# please read the SDK documents if you need to do this.
#

ifeq ("$(CONFIG_ESPHTTPD_USEYUICOMPRESSOR)","y")
USE_YUI_COMPRESSOR = y
endif
USE_YUI_COMPRESSOR ?= n

echo "Compressor: $(USE_YUI_COMPRESSOR)"

ifeq ("$(CONFIG_USE_HEATSHRINK)","y")
USE_HEATSHRINK = y
endif
USE_HEATSHRINK ?= n

ifeq ("$(CONFIG_GZIP_COMPRESSION)","y")
GZIP_COMPRESSION = y
endif
GZIP_COMPRESSION ?= n

ifeq ("$(CONFIG_SUPPORT_WEBSOCKETS)","y")
HTTPD_WEBSOCKETS = y
endif
HTTPD_WEBSOCKETS ?= n

ifneq ("$(CONFIG_ESPHTTPD_MAX_CONNECTIONS)","")
HTTPD_MAX_CONNECTIONS = $(ESPHTTPD_MAX_CONNECTIONS)
endif
HTTPD_MAX_CONNECTIONS ?= 4

YUI-COMPRESSOR ?= /usr/bin/yui-compressor

ifeq ("$(GZIP_COMPRESSION)","y")
CFLAGS		+= -DGZIP_COMPRESSION
endif

ifeq ("$(USE_HEATSHRINK)","y")
CFLAGS		+= -DESPFS_HEATSHRINK
endif

ifeq ("$(HTTPD_WEBSOCKETS)","y")
CFLAGS		+= -DHTTPD_WEBSOCKETS
endif

#For FreeRTOS
COMPONENT_SRCDIRS := core espfs util
COMPONENT_ADD_INCLUDEDIRS := core espfs util include lib/heatshrink
COMPONENT_ADD_LDFLAGS := -lwebpages-espfs -llibesphttpd

COMPONENT_EXTRA_CLEAN := mkespfsimage/*

HTMLDIR := $(subst ",,$(CONFIG_ESPHTTPD_HTMLDIR))

CFLAGS += -DFREERTOS

liblibesphttpd.a: libwebpages-espfs.a

webpages.espfs: $(PROJECT_PATH)/$(HTMLDIR) mkespfsimage/mkespfsimage
ifeq ("$(USE_YUI_COMPRESSOR)","y")
	rm -rf html_compressed;
	cp -r $(PROJECT_PATH)/$(HTMLDIR) html_compressed;
	echo "Compression assets with yui-compressor. This may take a while..."
	for file in `find html_compressed -type f -name "*.js"`; do $(YUI-COMPRESSOR) --type js $$file -o $$file; done
	for file in `find html_compressed -type f -name "*.css"`; do $(YUI-COMPRESSOR) --type css $$file -o $$file; done
	awk "BEGIN {printf \"YUI compression ratio was: %.2f%%\\n\", (`du -b -s html_compressed/ | sed 's/\([0-9]*\).*/\1/'`/`du -b -s $(PROJECT_PATH)/$(HTMLDIR) | sed 's/\([0-9]*\).*/\1/'`)*100}"
# mkespfsimage will compress html, css, svg and js files with gzip by default if enabled
# override with -g cmdline parameter
	cd html_compressed; find . | $(COMPONENT_BUILD_DIR)/mkespfsimage/mkespfsimage > $(COMPONENT_BUILD_DIR)/webpages.espfs; cd ..;
else
	cd $(PROJECT_PATH)/$(HTMLDIR) && find . | $(COMPONENT_BUILD_DIR)/mkespfsimage/mkespfsimage > $(COMPONENT_BUILD_DIR)/webpages.espfs
endif

libwebpages-espfs.a: webpages.espfs
	$(OBJCOPY) -I binary -O elf32-xtensa-le -B xtensa --rename-section .data=.rodata \
		webpages.espfs webpages.espfs.o.tmp
	$(CC) -nostdlib -Wl,-r webpages.espfs.o.tmp -o webpages.espfs.o -Wl,-T $(COMPONENT_PATH)/webpages.espfs.esp32.ld
	$(AR) cru $@ webpages.espfs.o

mkespfsimage/mkespfsimage: $(COMPONENT_PATH)/espfs/mkespfsimage
	mkdir -p $(COMPONENT_BUILD_DIR)/mkespfsimage
	$(MAKE) -C $(COMPONENT_BUILD_DIR)/mkespfsimage -f $(COMPONENT_PATH)/espfs/mkespfsimage/Makefile \
		USE_HEATSHRINK="$(USE_HEATSHRINK)" GZIP_COMPRESSION="$(GZIP_COMPRESSION)" BUILD_DIR=$(COMPONENT_BUILD_DIR)/mkespfsimage \
		CC=$(HOSTCC) 
