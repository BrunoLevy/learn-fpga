###############################################################################
# Inputs
###############################################################################
# SRC_DIR
# INCLUDE_PATH
# LIBNAME
# EXTRA_CFLAGS
# EXTRA_LIBS
# EXTRA_LIBDIRS
# GCC_PREFIX     = arch-toolchain-
# OPT            = [0-2]
# FPIC           = yes | no
# ARCH
# ARCH_CFLAGS
# ARCH_LFLAGS
# SHARED_LIB     = yes | no
# COMPILER       = g++ | gcc

###############################################################################
# Defaults
###############################################################################
SRC_DIR ?= .
LIBNAME ?= libfatfs.a

###############################################################################
# Variables
###############################################################################
OBJ_DIR      ?= obj/
DEP_DIR      ?= dep/
LIB_DIR      ?= lib/

###############################################################################
# Variables: GCC
###############################################################################
QUIET        ?= yes

GCC_PREFIX   ?= 
COMPILER     ?= g++

ifeq ($(QUIET),yes)
GCC          = @$(GCC_PREFIX)$(COMPILER)
AR           = @$(GCC_PREFIX)ar
else
GCC          = $(GCC_PREFIX)$(COMPILER)
AR           = $(GCC_PREFIX)ar
endif

###############################################################################
# Variables: Compilation flags
###############################################################################

# Additional include directories
INCLUDE_PATH += $(SRC_DIR)

OPT          ?= 2
FPIC         ?= yes
SHARED_LIB   ?= yes

# Flags
CFLAGS       = $(ARCH_CFLAGS) -O$(OPT)
ifeq ($(FPIC), yes)
CFLAGS       += -fpic
endif
CFLAGS       += $(patsubst %,-I%,$(INCLUDE_PATH))
CFLAGS       += $(EXTRA_CFLAGS)

LFLAGS        = $(ARCH_LFLAGS)
LFLAGS       += $(patsubst %,-L%,$(EXTRA_LIBDIRS))
LFLAGS       += $(EXTRA_LIBS)

###############################################################################
# Variables: Lists of objects, source and deps
###############################################################################
# SRC / Object list
src2obj       = $(OBJ_DIR)$(patsubst %$(suffix $(1)),%.o,$(notdir $(1)))
src2dep       = $(DEP_DIR)$(patsubst %,%.d,$(notdir $(1)))

SRC          ?= $(foreach src,$(SRC_DIR),$(wildcard $(src)/*.cpp)) $(foreach src,$(SRC_DIR),$(wildcard $(src)/*.c))
OBJ          ?= $(foreach src,$(SRC),$(call src2obj,$(src)))
DEPS         ?= $(foreach src,$(SRC),$(call src2dep,$(src)))

###############################################################################
# Rules: Compilation macro
###############################################################################
# Dependancy generation
DEPFLAGS      = -MT $$@ -MMD -MP -MF $(call src2dep,$(1))

define template_c
$(call src2obj,$(1)): $(1) | $(OBJ_DIR) $(DEP_DIR)
	@echo "# Compiling $(notdir $(1))"
	$(GCC) $(CFLAGS) $(DEPFLAGS) -c $$< -o $$@
endef

###############################################################################
# Rules
###############################################################################
all: $(LIB_DIR)$(LIBNAME)

$(OBJ_DIR) $(DEP_DIR) $(LIB_DIR):
	@mkdir -p $@

$(foreach src,$(SRC),$(eval $(call template_c,$(src))))

$(LIB_DIR)$(LIBNAME): $(OBJ) | $(LIB_DIR) 
	@echo "# Linking $(notdir $@)"
ifeq ($(SHARED_LIB),yes)
	$(GCC) -shared -o $@ $(LFLAGS) $(OBJ)
else
	$(AR) rcs $@ $(OBJ)
endif

clean:
	rm -rf $(LIB_DIR) $(OBJ_DIR) $(DEP_DIR)

###############################################################################
# Rules: Dependancies
###############################################################################
EXCLUDE_DEPS := clean
ifeq (0, $(words $(findstring $(MAKECMDGOALS), $(EXCLUDE_DEPS))))
-include $(DEPS)
endif
