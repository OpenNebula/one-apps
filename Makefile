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
packer-%: ${DIR_EXPORT}/%.qcow2
	@${INFO} "Packer ${*} done"

packer-service_Wordpress: packer-alma8 ${DIR_EXPORT}/service_Wordpress.qcow2
	@${INFO} "Packer service_Wordpress done"

# Define if your appliance depends on a distro. This example builds on top of alma8 packer build
packer-service_example: packer-alma8 ${DIR_EXPORT}/service_example.qcow2
	@${INFO} "Packer service_example done"

packer-service_VRouter: packer-alpine319 ${DIR_EXPORT}/service_VRouter.qcow2
	@${INFO} "Packer service_VRouter done"

packer-service_Harbor: packer-ubuntu2204 ${DIR_EXPORT}/service_Harbor.qcow2
	@${INFO} "Packer service_Harbor done"

packer-service_MinIO: packer-ubuntu2204 ${DIR_EXPORT}/service_MinIO.qcow2
	@${INFO} "Packer service_MinIO done"

packer-service_OneKE: packer-ubuntu2204 ${DIR_EXPORT}/service_OneKE.qcow2
	@${INFO} "Packer service_OneKE done"

# airgapped version
packer-service_OneKEa: PKR_VAR_airgapped := YES
packer-service_OneKEa: packer-ubuntu2204 ${DIR_EXPORT}/service_OneKEa.qcow2
	@${INFO} "Packer service_OneKEa done"

# run packer build for given distro or service
${DIR_EXPORT}/%.qcow2: $(patsubst %, context-linux/out/%, $(LINUX_CONTEXT_PACKAGES))
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

# context iso with all the context packages
context-iso: ${DIR_EXPORT}/one-context-$(VERSION)-$(RELEASE).iso
${DIR_EXPORT}/one-context-$(VERSION)-$(RELEASE).iso: \
	$(patsubst %, context-linux/out/%, $(LINUX_CONTEXT_PACKAGES)) \
	$(patsubst %, context-windows/out/%, $(WINDOWS_CONTEXT_PACKAGES))
	mkisofs -J -R -input-charset utf8 -m '*.iso' -V one-context-$(VERSION) -o ${DIR_EXPORT}/one-context.iso  context-linux/out/one-context?${VERSION}* context-windows/out/one-context-${VERSION}*.msi

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
