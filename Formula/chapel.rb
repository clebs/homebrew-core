  revision 1
  depends_on "python@3.10"
  # Include changes for Python 3.10 migration
  # They are already merged upstream after 1.25.1
  # TODO: Remove this in the next release
      with_env(CHPL_PIP_FROM_SOURCE: "1") do
      with_env(CHPL_PIP_FROM_SOURCE: "1") do
@@ -6,6 +6,13 @@ CHPL_MAKE_HOST_TARGET = --host
 include $(CHPL_MAKE_HOME)/make/Makefile.base
 include $(THIRD_PARTY_DIR)/chpl-venv/Makefile.include

+# CHPL_PIP_INSTALL_PARAMS can be set to adjust the pip arguments,
+# but if you want to build from source, set CHPL_PIP_FROM_SOURCE
+
+ifdef CHPL_PIP_FROM_SOURCE
+  CHPL_PIP_INSTALL_PARAMS=--no-binary :all:
+endif
+
 default: all

 all: test-venv chpldoc-venv
@@ -20,51 +27,50 @@ clobber: FORCE clean

 OLD_PYTHON_ERROR="python3 version 3.5 or later is required to install chpldoc and start_test dependencies. See https://www.python.org/"

-# Create the virtualenv to use during build.
-#  (to allow for a different path to the system python3 in the future)
-$(CHPL_VENV_VIRTUALENV_DIR_OK):
+$(CHPL_VENV_VIRTUALENV_DIR_DEPS1_OK):

+	@# Now install wheel so we can pip install
+	export PATH="$(CHPL_VENV_VIRTUALENV_BIN):$$PATH" && \
+	export VIRTUAL_ENV=$(CHPL_VENV_VIRTUALENV_DIR) && \
+	$(PIP) install --upgrade \
+	  $(CHPL_PIP_INSTALL_PARAMS) $(LOCAL_PIP_FLAGS) wheel && \
+	touch $(CHPL_VENV_VIRTUALENV_DIR_DEPS1_OK)
+
+ifdef CHPL_PIP_FROM_SOURCE
+$(CHPL_VENV_VIRTUALENV_DIR_DEPS2_OK): $(CHPL_VENV_VIRTUALENV_DIR_DEPS1_OK)
+	@# Now install source dependencies so we can build from source
+	$(PIP) install --upgrade \
+	  $(CHPL_PIP_INSTALL_PARAMS) $(LOCAL_PIP_FLAGS) \
+	$(PIP) install --upgrade \
+	   $(CHPL_PIP_INSTALL_PARAMS) $(LOCAL_PIP_FLAGS) \
+	   -r $(CHPL_VENV_CHPLDOC_REQUIREMENTS_FILE2) && \
+	touch $(CHPL_VENV_VIRTUALENV_DIR_DEPS2_OK)
+
+else
+$(CHPL_VENV_VIRTUALENV_DIR_DEPS2_OK): $(CHPL_VENV_VIRTUALENV_DIR_DEPS1_OK)
+	touch $(CHPL_VENV_VIRTUALENV_DIR_DEPS2_OK)
+
+endif
+
+# Create the virtualenv to use during build.
+#  (to allow for a different path to the system python3 in the future)
+$(CHPL_VENV_VIRTUALENV_DIR_OK): $(CHPL_VENV_VIRTUALENV_DIR_DEPS1_OK) $(CHPL_VENV_VIRTUALENV_DIR_DEPS2_OK)


@@ -72,7 +78,9 @@ $(CHPL_VENV_CHPLDEPS_MAIN): $(CHPL_VENV_VIRTUALENV_DIR_OK) $(CHPL_VENV_TEST_REQU

@@ -89,8 +97,7 @@ install-requirements: install-chpldeps



@@ -23,6 +25,8 @@ PIP=$(PYTHON) -m pip
 CHPL_VENV_BUILD=$(CHPL_VENV_DIR)/build
 CHPL_VENV_VIRTUALENV_DIR=$(CHPL_VENV_BUILD)/build-venv
 CHPL_VENV_VIRTUALENV_DIR_OK=$(CHPL_VENV_BUILD)/build-venv/ok
+CHPL_VENV_VIRTUALENV_DIR_DEPS1_OK=$(CHPL_VENV_BUILD)/build-venv/ok1
+CHPL_VENV_VIRTUALENV_DIR_DEPS2_OK=$(CHPL_VENV_BUILD)/build-venv/ok2
 CHPL_VENV_VIRTUALENV_BIN=$(CHPL_VENV_VIRTUALENV_DIR)/bin
 CHPL_VENV_INSTALL=$(CHPL_VENV_DIR)/install
 CHPL_VENV_CHPLDEPS=$(CHPL_VENV_INSTALL)/chpldeps

+++ /dev/null
@@ -1,9 +0,0 @@
-Jinja2==3.0.1
-MarkupSafe==2.0.1
-Pygments==2.9.0
-Sphinx==4.0.2
-docutils==0.16.0
-sphinxcontrib-chapeldomain==0.0.20
-babel==2.9.1
-breathe==4.30.0

@@ -0,0 +1,2 @@
+# Split into 3 files to work around problems with CHPL_PIP_FROM_SOURCE

@@ -0,0 +1,6 @@
+# Split into 3 files to work around problems with CHPL_PIP_FROM_SOURCE
+Sphinx==4.3.2

@@ -0,0 +1,4 @@
+# Split into 3 files to work around problems with CHPL_PIP_FROM_SOURCE
+sphinxcontrib-chapeldomain==0.0.21
+breathe==4.31.0
@@ -110,10 +110,16 @@ def check_llvm_config(llvm_config):

         paths.append("llvm-config-" + vers)
+        # this format used by freebsd
+        paths.append("llvm-config" + vers)
         # next ones are for Homebrew
         paths.append("/usr/local/opt/llvm@" + vers + ".0/bin/llvm-config")
         paths.append("/usr/local/opt/llvm@" + vers + "/bin/llvm-config")
@@ -299,7 +305,14 @@ def llvm_enabled():
 def get_gcc_prefix():
     gcc_prefix = overrides.get('CHPL_LLVM_GCC_PREFIX', '')

+
     if not gcc_prefix:
+        # darwin and FreeBSD default to clang
+        # so shouldn't need GCC prefix
+        host_platform = chpl_platform.get('host')
+        if host_platform == "darwin" or host_platform == "freebsd":
+            return ''
+
         # When 'gcc' is a command other than '/usr/bin/gcc',
         # compute the 'gcc' prefix that LLVM should use.
         gcc_path = find_executable('gcc')
@@ -402,12 +415,16 @@ def get_clang_additional_args():



--- a/util/chplenv/chpl_compiler.py
+++ b/util/chplenv/chpl_compiler.py
@@ -1,10 +1,9 @@
 #!/usr/bin/env python3
 import optparse
 import os
+import shutil
 import sys

-from distutils.spawn import find_executable
-
 import chpl_platform, overrides
 from utils import error, memoize, warning

@@ -193,7 +192,7 @@ def get(flag='host'):
         elif platform_val.startswith('pwr'):
             compiler_val = 'ibm'
         elif platform_val == 'darwin' or platform_val == 'freebsd':
-            if find_executable('clang'):
+            if shutil.which('clang'):
                 compiler_val = 'clang'
             else:
                 compiler_val = 'gnu'

--- a/util/chplenv/chpl_launcher.py
+++ b/util/chplenv/chpl_launcher.py
@@ -1,5 +1,5 @@
 #!/usr/bin/env python3
-from distutils.spawn import find_executable
+import shutil
 import sys

 import chpl_comm, chpl_comm_substrate, chpl_platform, overrides
@@ -7,7 +7,7 @@ from utils import error, memoize, warning

 def slurm_prefix(base_launcher, platform_val):
     """ If salloc is available and we're on a cray-cs/hpe-apollo, prefix with slurm-"""
-    if platform_val in ('cray-cs', 'hpe-apollo') and find_executable('salloc'):
+    if platform_val in ('cray-cs', 'hpe-apollo') and shutil.which('salloc'):
         return 'slurm-{}'.format(base_launcher)
     return base_launcher

@@ -29,8 +29,8 @@ def get():
         platform_val = chpl_platform.get('target')

         if platform_val.startswith('cray-x') or platform_val.startswith('hpe-cray-'):
-            has_aprun = find_executable('aprun')
-            has_slurm = find_executable('srun')
+            has_aprun = shutil.which('aprun')
+            has_slurm = shutil.which('srun')
             if has_aprun and has_slurm:
                 launcher_val = 'none'
             elif has_aprun:
@@ -60,7 +60,7 @@ def get():
             elif substrate_val == 'ofi':
                 launcher_val = slurm_prefix('gasnetrun_ofi', platform_val)
         else:
-            if platform_val in ('cray-cs', 'hpe-apollo') and find_executable('srun'):
+            if platform_val in ('cray-cs', 'hpe-apollo') and shutil.which('srun'):
                 launcher_val = 'slurm-srun'
             else:
                 launcher_val = 'none'

--- a/util/chplenv/chpl_llvm.py
+++ b/util/chplenv/chpl_llvm.py
@@ -1,8 +1,8 @@
 #!/usr/bin/env python3
 import optparse
 import os
+import shutil
 import sys
-from distutils.spawn import find_executable
 import re

 import chpl_bin_subdir, chpl_arch, chpl_compiler, chpl_platform, overrides
@@ -302,7 +302,7 @@ def get_gcc_prefix():
     if not gcc_prefix:
         # When 'gcc' is a command other than '/usr/bin/gcc',
         # compute the 'gcc' prefix that LLVM should use.
-        gcc_path = find_executable('gcc')
+        gcc_path = shutil.which('gcc')
         if gcc_path == '/usr/bin/gcc' :
             # In this common case, nothing else needs to be done,
             # because we can assume that clang can find this gcc.

--- a/util/chplenv/chpl_make.py
+++ b/util/chplenv/chpl_make.py
@@ -1,5 +1,5 @@
 #!/usr/bin/env python3
-from distutils.spawn import find_executable
+import shutil
 import sys

 import chpl_platform, overrides
@@ -14,7 +14,7 @@ def get():
         if platform_val.startswith('cygwin') or platform_val == 'darwin':
             make_val = 'make'
         elif platform_val.startswith('linux'):
-            if find_executable('gmake'):
+            if shutil.which('gmake'):
                 make_val = 'gmake'
             else:
                 make_val = 'make'