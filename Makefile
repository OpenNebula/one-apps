# load variables and makefile config
include Makefile.config

# load possible overrides or non-free definitions
-include Makefile.local

# all, aliases
all: $(patsubst %, packer-%, $(DISTROS)) $(patsubst %, packer-%, $(SERVICES))
distros: $(patsubst %, packer-%, $(DISTROS))
services: $(patsubst %, alma-based-%, $(SERVICES))

# allow individual distribution targets (e.g., "make debian11")
$(DISTROS):  %: packer-% ;
$(SERVICES): %: alma-based-% ;

# build using packer
packer-%: context-linux ${DIR_EXPORT}/%.qcow2
	@${INFO} "Packer ${*} done"

alma-based-%: packer-alma8 ${DIR_EXPORT}/%.qcow2
	@${INFO} "Packer ${*} done"

# run packer build for given distro or service
${DIR_EXPORT}/%.qcow2:
	$(eval DISTRO_NAME := $(shell echo ${*} | sed 's/[0-9].*//'))
	$(eval DISTRO_VER  := $(shell echo ${*} | sed 's/[a-z_]*//'))
	packer/build.sh "${DISTRO_NAME}" "${DISTRO_VER}" ${@}

# context packages
context-linux: $(patsubst %, context-linux/out/%, $(LINUX_CONTEXT_PACKAGES))
	@${INFO} "Generate context-linux done"

context-linux/out/%:
	cd context-linux; ./generate-all.sh

clean:
	-rm -rf ${DIR_EXPORT}/*

help:
	@echo 'Available distros:'
	@echo "$(shell echo "${DISTROS}" | fmt -w 65 | tr '\n' '\1' )" \
		           | tr '\1' '\n' | sed 's/^/    /'
	@echo 'Available services:'
	@echo '    $(SERVICES)'
	@echo
	@echo 'Usage examples:'
	@echo '    make all               -- build all distros and services'
	@echo '    make distros           -- build all distros'
	@echo '    make services          -- build all services'
	@echo
	@echo '    make <distro>          -- build just one distro'
	@echo '    make context-linux     -- build context linux packages'
	@echo '    make context-windows   -- TODO'

version:
	@echo $(VERSION)-$(RELEASE) > version
