#_______________________________________________________________________________
#
#                         edam's Arduino makefile
#_______________________________________________________________________________
#                                                                    version 0.4
#
# Copyright (C) 2011, 2012 Tim Marston <tim@ed.am>.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#_______________________________________________________________________________
#
#
# This is a general purpose makefile for use with Arduino hardware and
# software.  It works with the arduino-1.0 software release.  To download the
# latest version of this makefile, visit the following website, where you can
# also find more information and documentation on it's use.  The following text
# can only really be considered a reference to it's use.
#
#   http://ed.am/dev/make/arduino-mk
#
# This makefile can be used as a drop-in replacement for the Arduino IDE's
# build system.  To use it, save arduino.mk somewhere (I keep mine at
# ~/src/arduino.mk) and create a symlink to it in your project directory named
# "Makefile".  For example:
#
#   $ ln -s ~/src/arduino.mk Makefile
#
# The Arduino software (version 1.0 or later) is required.  If you are using
# Debian (or a derivative), type `apt-get install arduino`.  Otherwise, you
# will have to download the Arduino software manually from http://arduino.cc/.
# It is suggested that you install it at ~/opt/arduino if you are unsure.
#
# If you downloaded the Arduino software manually and unpacked it somewhere
# other than ~/opt/arduino, you will need to set up ARDUINODIR to be the path
# where you unpacked it.  (If unset, ARDUINODIR defaults to ~/opt/arduino and
# then /usr/share/arduino, in that order.)  You might be best to set this in
# your ~/.profile by adding something like this:
#
#   export ARDUINODIR=~/somewhere/arduino-1.0
#
# You will also need to set BOARD to the type of Arduino you're building for.
# Type `make boards` for a list of acceptable values.  You could set a default
# in your ~/.profile if you want, but it is suggested that you specify this at
# build time, especially if you work with different types of Arduino.  For
# example:
#
#   $ export BOARD=uno
#   $ make
#
# You may also need to set SERIALDEV if it is not detected correctly.
#
# The presence of a .ino (or .pde) file causes the arduino.mk to automatically
# determine values for SOURCES, TARGET and LIBRARIES.  Any .c, .cc and .cpp
# files in the project directory (or any "util" or "utility" subdirectories)
# are automatically included in the build and are scanned for Arduino libraries
# that have been #included. Note, there can only be one .ino (or .pde) file.
#
# Alternatively, if you want to manually specify build variables, create a
# Makefile that defines SOURCES and LIBRARIES and then includes arduino.mk.
# (There is no need to define TARGET).  Here is an example Makefile:
#
#   SOURCES := main.cc other.cc
#   LIBRARIES := EEPROM
#   include ~/src/arduino.mk
#
# Here is a complete list of configuration parameters:
#
# ARDUINODIR   The path where the Arduino software is installed on your system.
#
# ARDUINOCONST The Arduino software version, as an integer, used to define the
#              ARDUINO version constant. This defaults to 100 if undefined.
#
# AVRDUDECONF  The avrdude.conf to use. If undefined, this defaults to a guess
#              based on where the avrdude in use is. If empty, no avrdude.conf
#              is passed to avrdude (to the system default is used).
#
# AVRTOOLSPATH A space-separated list of directories to search in order when
#              looking for the avr build tools. This defaults to the system PATH
#              followed by subdirectories in ARDUINODIR if undefined.
#
# BOARD        Specify a target board type.  Run `make boards` to see available
#              board types.
#
# LIBRARIES    A list of Arduino libraries to build and include.  This is set
#              automatically if a .ino (or .pde) is found.
#
# SERIALDEV    The unix device name of the serial device that is the Arduino.
#              If unspecified, an attempt is made to determine the name of a
#              connected Arduino's serial device.
#
# SOURCES      A list of all source files of whatever language.  The language
#              type is determined by the file extension.  This is set
#              automatically if a .ino (or .pde) is found.
#
# TARGET       The name of the target file.  This is set automatically if a
#              .ino (or .pde) is found, but it is not necessary to set it
#              otherwise.
#
# This makefile also defines the following goals for use on the command line
# when you run make:
#
# all          This is the default if no goal is specified.  It builds the
#              target.
#
# target       Builds the target.
#
# upload       Uploads the last built target to an attached Arduino.
#
# clean        Deletes files created during the build.
#
# boards       Display a list of available board names, so that you can set the
#              BOARD environment variable appropriately.
#
# monitor      Start `screen` on the serial device.  This is meant to be an
#              equivalent to the Arduino serial monitor.
#
# size         Displays size information about the bulit target.
#
# <file>       Builds the specified file, either an object file or the target,
#              from those that that would be built for the project.
#_______________________________________________________________________________
#

# default arduino software directory, check software exists
ifndef ARDUINODIR
ARDUINODIR := $(firstword $(wildcard ~/opt/arduino /usr/share/arduino))
endif
ifeq "$(wildcard $(ARDUINODIR)/hardware/arduino/boards.txt)" ""
# XXX 1.6.4 ifeq "$(wildcard $(ARDUINODIR)/hardware/arduino/avr/boards.txt)" ""
$(error ARDUINODIR is not set correctly; arduino software not found)
endif


# default arduino version
ARDUINOCONST ?= 104

# default path for avr tools
ifndef AVRTOOLSPATH
AVRTOOLSPATH := $(subst :, , $(PATH))
AVRTOOLSPATH += $(ARDUINODIR)/hardware/tools
AVRTOOLSPATH += $(ARDUINODIR)/hardware/tools/avr/bin
endif

# auto mode?
INOFILE := $(wildcard *.ino *.pde)
ifdef INOFILE
ifneq "$(words $(INOFILE))" "1"
$(error There is more than one .pde or .ino file in this directory!)
endif

# automatically determine sources and targeet
TARGET := $(basename $(INOFILE))
SOURCES := $(INOFILE) \
	$(wildcard *.c *.cc *.cpp) \
	$(wildcard $(addprefix util/, *.c *.cc *.cpp)) \
	$(wildcard $(addprefix utility/, *.c *.cc *.cpp))

# automatically determine included libraries
LIBRARIES := \
	$(shell sed -ne "s/^ *\# *include *[<\"]\(.*\)\.h[>\"]/\1/p" $(SOURCES))

endif

# no serial device? make a poor attempt to detect an arduino
SERIALDEVGUESS := 0
ifeq "$(SERIALDEV)" ""
SERIALDEV := $(firstword $(wildcard \
	/dev/ttyACM? /dev/ttyUSB? /dev/tty.usbserial* /dev/tty.usbmodem*))
SERIALDEVGUESS := 1
endif

# software
findsoftware = $(firstword $(wildcard $(addsuffix /$(1), $(AVRTOOLSPATH))))
CC := $(call findsoftware,avr-gcc)
CXX := $(call findsoftware,avr-g++)
LD := $(call findsoftware,avr-ld)
AR := $(call findsoftware,avr-ar)
OBJCOPY := $(call findsoftware,avr-objcopy)
AVRDUDE := $(call findsoftware,avrdude)
AVRSIZE := $(call findsoftware,avr-size)

# files
TARGET := $(if $(TARGET),$(TARGET),a.out)
OBJECTS := $(addsuffix .o, $(basename $(SOURCES)))
DEPFILES := $(patsubst %, .dep/%.dep, $(SOURCES))
ARDUINOCOREDIR := $(ARDUINODIR)/hardware/arduino/cores/arduino
ARDUINOLIB := .lib/arduino.a
ARDUINOLIBLIBSDIR := $(ARDUINODIR)/libraries
ARDUINOLIBLIBSPATH := $(foreach lib, $(LIBRARIES), \
	$(ARDUINODIR)/libraries/$(lib) $(ARDUINODIR)/libraries/$(lib)/utility )
ARDUINOLIBOBJS := $(foreach dir, $(ARDUINOCOREDIR) $(ARDUINOLIBLIBSPATH), \
	$(patsubst %, .lib/%.o, $(wildcard $(addprefix $(dir)/, *.c *.cpp))))
#$(info OBJECTS $(ARDUINOLIBOBJS))
ifeq "$(AVRDUDECONF)" ""
ifeq "$(AVRDUDE)" "$(ARDUINODIR)/hardware/tools/avr/bin/avrdude"
AVRDUDECONF := $(ARDUINODIR)/hardware/tools/avr/etc/avrdude.conf
else
AVRDUDECONF := $(wildcard $(AVRDUDE).conf)
endif
endif

# no board?
ifndef BOARD
ifneq "$(MAKECMDGOALS)" "boards"
ifneq "$(MAKECMDGOALS)" "clean"
$(error BOARD is unset.  Type 'make boards' to see possible values)
endif
endif
endif

# obtain board parameters from the arduino boards.txt file
# 1.6.4 BOARDS_FILE := $(ARDUINODIR)/hardware/arduino/avr/boards.txt
BOARDS_FILE := $(ARDUINODIR)/hardware/arduino/boards.txt
BOARD_BUILD_MCU := \
	$(shell sed -ne "s/$(BOARD).build.mcu=\(.*\)/\1/p" $(BOARDS_FILE))
BOARD_BUILD_FCPU := \
	$(shell sed -ne "s/$(BOARD).build.f_cpu=\(.*\)/\1/p" $(BOARDS_FILE))
BOARD_BUILD_VARIANT := \
	$(shell sed -ne "s/$(BOARD).build.variant=\(.*\)/\1/p" $(BOARDS_FILE))
BOARD_UPLOAD_SPEED := \
	$(shell sed -ne "s/$(BOARD).upload.speed=\(.*\)/\1/p" $(BOARDS_FILE))
BOARD_UPLOAD_PROTOCOL := \
	$(shell sed -ne "s/$(BOARD).upload.protocol=\(.*\)/\1/p" $(BOARDS_FILE))
BOARD_USB_VID := \
	$(shell sed -ne "s/$(BOARD).build.vid=\(.*\)/\1/p" $(BOARDS_FILE))
BOARD_USB_PID := \
	$(shell sed -ne "s/$(BOARD).build.pid=\(.*\)/\1/p" $(BOARDS_FILE))

# invalid board?
ifeq "$(BOARD_BUILD_MCU)" ""
ifneq "$(MAKECMDGOALS)" "boards"
ifneq "$(MAKECMDGOALS)" "clean"
$(error BOARD is invalid.  Type 'make boards' to see possible values)
endif
endif
endif

# flags
CPPFLAGS := -Os -fno-exceptions -ffunction-sections -fdata-sections
CPPFLAGS += -g
CPPFLAGS += -Wall
#CPPFLAGS += -fpermissive
CPPFLAGS += -Wunused-variable
CPPFLAGS += -funsigned-char -funsigned-bitfields -fpack-struct -fshort-enums
CPPFLAGS += -mmcu=$(BOARD_BUILD_MCU)
CPPFLAGS += -DF_CPU=$(BOARD_BUILD_FCPU) -DARDUINO=$(ARDUINOCONST)
CPPFLAGS += -DUSB_VID=$(BOARD_USB_VID) -DUSB_PID=$(BOARD_USB_PID)
CPPFLAGS += -I. -Iutil -Iutility 
CPPFLAGS += -I$(ARDUINOCOREDIR)
CPPFLAGS += -I$(ARDUINODIR)/hardware/arduino/variants/$(BOARD_BUILD_VARIANT)/
CPPFLAGS += $(addprefix -I$(ARDUINODIR)/libraries/, $(LIBRARIES))
CPPFLAGS += $(patsubst %, -I $(ARDUINODIR)/libraries/%/utility, $(LIBRARIES))
#CPPFLAGS += -I$(ARDUINODIR)/libraries/
CPPDEPFLAGS = -MMD -MP -MF .dep/$<.dep
#CPPDEPFLAGS = -MMD
CPPPDEFLAGS := -x c++ -include $(ARDUINOCOREDIR)/Arduino.h
CPPINOFLAGS := $(CPPPDEFLAGS)
AVRDUDEFLAGS := $(addprefix -C , $(AVRDUDECONF)) -DV
AVRDUDEFLAGS += -p $(BOARD_BUILD_MCU) -P $(SERIALDEV)
AVRDUDEFLAGS += -c $(BOARD_UPLOAD_PROTOCOL) -b $(BOARD_UPLOAD_SPEED)
LINKFLAGS := -Os -Wl,--gc-sections -mmcu=$(BOARD_BUILD_MCU)

# figure out which arg to use with stty (for OS X, GNU and busybox stty)
STTYFARG := $(shell stty --help 2>&1 | \
	grep -q 'illegal option' && echo -f || echo -F)

# include dependencies
ifneq "$(MAKECMDGOALS)" "clean"
-include $(DEPFILES)
endif


ll                  = /srv/project-mpe/mkdoc/usr/share/mkdoc/Core/log.sh
#ll                  = /usr/share/mkdoc/Core/log.sh
#ll                  = log.sh

ARDUINODIRLIB=$(ARDUINODIR)/libraries
#compiledLIB=.lib/$(ARDUINOCOREDIR)
define readable-path
$(subst $(BOARDS_FILE),BOARDS_FILE:,$(subst $(ARDUINOCOREDIR)/,ARDUINOCOREDIR:,$(subst $(ARDUINODIRLIB)/,ARDUINODIRLIB:,$1)))
endef
#(subst $(myLIB),myLIB:,$1))))
#readable_path_vars = BOARDS_FILE ARDUINOCOREDIR ARDUINODIRLIB myLIB
	#$(foreach var,$(readable_path_vars),$(subst $($(var)),$(var):,$1)))

define alog
	$(ll) "$1" "$(call readable-path,$2)" "$3" "$(call readable-path,$4)"
endef

$(info $(shell $(call alog,header2,ARDUINODIR,$(ARDUINODIR) )))
$(info $(shell $(call alog,header2,Working dir,$(shell pwd) )))
$(info $(shell $(call alog,header2,SOURCES,$(SOURCES) )))
$(info $(shell $(call alog,header2,LIBRARIES,$(LIBRARIES) )))
$(info $(shell $(call alog,header2,TARGET,$(TARGET).hex )))


# default rule
.DEFAULT_GOAL := all

#_______________________________________________________________________________
#                                                                          RULES

.PHONY:	all target upload clean boards monitor size

all: target

target: $(TARGET).hex

upload: target
	@$(call alog,attention,$@,Uploading...,$(SERIALDEV))
	@test -n "$(SERIALDEV)" || { \
		echo "error: SERIALDEV could not be determined automatically." >&2; \
		exit 1; }
	@test 0 -eq $(SERIALDEVGUESS) || { \
		echo "*GUESSING* at serial device:" $(SERIALDEV); \
		echo; }
	stty $(STTYFARG) $(SERIALDEV) hupcl
	$(AVRDUDE) $(AVRDUDEFLAGS) -U flash:w:$(TARGET).hex:i

clean:
	@$(call alog,attention,$@,Cleaning...,$(SERIALDEV))
	@rm -f $(OBJECTS) $(TARGET).elf $(TARGET).hex $(ARDUINOLIB) *~
	@rm -rf .lib/$(ARDUINOCOREDIR) .dep

boards:
	@echo Available values for BOARD:
	@sed -nEe '/^#/d; /^[^.]+\.name=/p' $(BOARDS_FILE) | \
		sed -Ee 's/([^.]+)\.name=(.*)/\1            \2/' \
			-e 's/(.{12}) *(.*)/\1 \2/'

monitor:
	@test -n "$(SERIALDEV)" || { \
		echo "error: SERIALDEV could not be determined automatically." >&2; \
		exit 1; }
	@test -n `which screen` || { \
		echo "error: can't find GNU screen, you might need to install it." >&2 \
		ecit 1; }
	@test 0 -eq $(SERIALDEVGUESS) || { \
		echo "*GUESSING* at serial device:" $(SERIALDEV); \
		echo; }
	screen $(SERIALDEV)

size: $(TARGET).elf
	echo && $(AVRSIZE) --format=avr --mcu=$(BOARD_BUILD_MCU) $(TARGET).elf

# building the target

$(TARGET).hex: $(TARGET).elf
	@$(call alog,attention,$@,Building image...,$^)
	@$(OBJCOPY) -O ihex -R .eeprom $< $@
	@$(call alog,ok,$@,Done)

.INTERMEDIATE: $(TARGET).elf

#$(info $(COMPILE.cpp) $(CPPDEPFLAGS))

$(TARGET).elf: $(ARDUINOLIB) $(OBJECTS)
	@$(call alog,attention,$@,Packing...,$^)
	$(CC) $(LINKFLAGS) $(OBJECTS) $(ARDUINOLIB) -lm -o $@
	@$(call alog,ok,$@,Done)

%.o: %.c
	@$(call alog,attention,$@,Compiling...,$^)
	@mkdir -p .dep/$(dir $<)
	@$(COMPILE.c) $(CPPDEPFLAGS) -o $@ $<
	@$(call alog,ok,$@,Done)

%.o: %.cpp
	@$(call alog,attention,$@,Compiling...,$^)
	@mkdir -p .dep/$(dir $<)
	@$(COMPILE.cpp) $(CPPDEPFLAGS) -o $@ $<
	@$(call alog,ok,$@,Done)

%.o: %.cc
	@$(call alog,attention,$@,Compiling...,$^)
	@mkdir -p .dep/$(dir $<)
	@$(COMPILE.cpp) $(CPPDEPFLAGS) -o $@ $<
	@$(call alog,ok,$@,Done)

%.o: %.C
	@$(call alog,attention,$@,Compiling...,$^)
	@mkdir -p .dep/$(dir $<)
	@$(COMPILE.cpp) $(CPPDEPFLAGS) -o $@ $<
	@$(call alog,ok,$@,Done)

%.o: %.ino
	@$(call alog,attention,$@,Compiling...,$^)
	@mkdir -p .dep/$(dir $<)
	@$(COMPILE.cpp) $(CPPDEPFLAGS) -o $@ $(CPPINOFLAGS) $<
	@$(call alog,ok,$@,Done)

%.o: %.pde
	@$(call alog,attention,$@,Compiling...,$^)
	@mkdir -p .dep/$(dir $<)
	@$(COMPILE.cpp) $(CPPDEPFLAGS) -o $@ $(CPPPDEFLAGS) $<
	@$(call alog,ok,$@,Done)

# building the arduino library

$(ARDUINOLIB): $(ARDUINOLIBOBJS)
	@$(call alog,attention,$@,Compiling...,$^)
	@$(AR) rcs $@ $?
	@$(call alog,ok,$@,Done)

.lib/%.c.o: %.c
	@$(call alog,attention,$@,Compiling...,$^)
	@mkdir -p $(dir $@)
	@$(COMPILE.c) -o $@ $<
	@$(call alog,ok,$@,Done)

.lib/%.cpp.o: %.cpp
	@$(call alog,attention,$@,Compiling...,$^)
	@mkdir -p $(dir $@)
	@$(COMPILE.cpp) -o $@ $<
	@$(call alog,ok,$@,Done)

.lib/%.cc.o: %.cc
	@$(call alog,attention,$@,Compiling...,$^)
	@mkdir -p $(dir $@)
	@$(COMPILE.cpp) -o $@ $<
	@$(call alog,ok,$@,Done)

.lib/%.C.o: %.C
	@$(call alog,attention,$@,Compiling...,$^)
	@mkdir -p $(dir $@)
	@$(COMPILE.cpp) -o $@ $<
	@$(call alog,ok,$@,Done)
