# load variables and makefile config
include Makefile.config

# load possible overrides or non-free definitions
-include Makefile.local

# all, aliases
all: $(patsubst %, packer-%, $(DISTROS)) $(patsubst %, packer-%, $(SERVICES))
distros: $(patsubst %, packer-%, $(DISTROS))
services: $(patsubst %, packer-%, $(SERVICES))

# allow individual distribution targets (e.g., "make debian11")
$(DISTROS) $(SERVICES):  %: packer-% ;

# aliases + dependency
packer-%: context-linux ${DIR_EXPORT}/%.qcow2
	@${INFO} "Packer ${*} done"

packer-service_vnf: packer-alpine318 ${DIR_EXPORT}/service_vnf.qcow2
	@${INFO} "Packer service_vnf done"

packer-service_wordpress: packer-alma8 ${DIR_EXPORT}/service_wordpress.qcow2
	@${INFO} "Packer service_wordpress done"

packer-service_VRouter: packer-alpine318 ${DIR_EXPORT}/service_VRouter.qcow2
	@${INFO} "Packer service_VRouter done"

packer-service_OneKE: packer-ubuntu2204 ${DIR_EXPORT}/service_OneKE.qcow2
	@${INFO} "Packer service_OneKE done"

# airgapped version
packer-service_OneKEa: PKR_VAR_airgapped := YES
packer-service_OneKEa: packer-ubuntu2204 ${DIR_EXPORT}/service_OneKEa.qcow2
	@${INFO} "Packer service_OneKEa done"

# run packer build for given distro or service
${DIR_EXPORT}/%.qcow2:
	$(eval DISTRO_NAME := $(shell echo ${*} | sed 's/[0-9].*//'))
	$(eval DISTRO_VER  := $(shell echo ${*} | sed 's/^.[^0-9]*\(.*\)/\1/'))
	packer/build.sh "${DISTRO_NAME}" "${DISTRO_VER}" ${@}

# context packages
context-linux: $(patsubst %, context-linux/out/%, $(LINUX_CONTEXT_PACKAGES))
	@${INFO} "Generate context-linux done"

context-linux/out/%: ${CONTEXT_LINUX_SOURCES}
	cd context-linux; ./generate-all.sh

context-windows: $(patsubst %, context-windows/out/%, $(WINDOWS_CONTEXT_PACKAGES))
	@${INFO} "Generate context-windows done"

context-windows/out/%: ${CONTEXT_WINDOWS_SOURCES}
	cd context-windows; ./generate-all.sh

clean:
	-rm -rf ${DIR_EXPORT}/*
	-rm -rf context-linux/out/*
	-rm -rf context-windows/out/*

help:
	@echo 'Usage examples:'
	@echo '    make <distro>          -- build just one distro'
	@echo '    make <service>         -- build just one service'
	@echo
	@echo '    make all               -- build all distros and services'
	@echo '    make all -j 4          -- build all in 4 parallel tasks'
	@echo '    make distros           -- build all distros'
	@echo '    make services          -- build all services'
	@echo
	@echo '    make context-linux     -- build context linux packages'
	@echo '    make context-windows   -- build windows linux packages'
	@echo
	@echo 'Available distros:'
	@echo "$(shell echo "${DISTROS}" | fmt -w 65 | tr '\n' '\1' )" \
		           | tr '\1' '\n' | sed 's/^/    /'
	@echo 'Available services:'
	@echo '    $(SERVICES)'
	@echo

version:
	@echo $(VERSION)-$(RELEASE) > version
