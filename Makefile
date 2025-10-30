.SECONDEXPANSION:

# load variables and makefile config
include Makefile.config

# load possible overrides or non-free definitions
-include Makefile.local

# aliases
distros-amd64: $(DISTROS_AMD64:%=packer-%)
distros-arm64: $(DISTROS_ARM64:%=packer-%)
services-amd64: $(SERVICES_AMD64:%=packer-%)
services-arm64: $(SERVICES_ARM64:%=packer-%)

# allow individual distribution targets (e.g., "make debian11")
$(DISTROS) $(SERVICES): %: packer-%

# aliases + dependency
packer-%: $(DIR_EXPORT)/%.qcow2
	@$(INFO) "Packer $* done"

packer-service_Wordpress: packer-alma8 $(DIR_EXPORT)/service_Wordpress.qcow2
	@$(INFO) "Packer service_Wordpress done"

# Define if your appliance depends on a distro. This example builds on top of alma8 packer build
packer-service_example: packer-alma8 $(DIR_EXPORT)/service_example.qcow2
	@$(INFO) "Packer service_example done"

packer-service_VRouter: packer-alpine320 $(DIR_EXPORT)/service_VRouter.qcow2
	@$(INFO) "Packer service_VRouter done"

packer-service_VRouter.aarch64: packer-alpine320.aarch64 $(DIR_EXPORT)/service_VRouter.aarch64.qcow2
	@$(INFO) "Packer service_VRouter.aarch64 done"

packer-service_Harbor: packer-ubuntu2204 $(DIR_EXPORT)/service_Harbor.qcow2
	@$(INFO) "Packer service_Harbor done"

packer-service_MinIO: packer-ubuntu2204 $(DIR_EXPORT)/service_MinIO.qcow2
	@$(INFO) "Packer service_MinIO done"

packer-service_OneKE: packer-ubuntu2204oneke $(DIR_EXPORT)/service_OneKE.qcow2 $(DIR_EXPORT)/service_OneKE_storage.qcow2
	@$(INFO) "Packer service_OneKE done"

packer-capone: packer-ubuntu2204oneke $(DIR_EXPORT)/capone.qcow2
	@$(INFO) "Packer capone done"

# airgapped version
packer-service_OneKEa: PKR_VAR_airgapped := YES
packer-service_OneKEa: packer-ubuntu2204oneke $(DIR_EXPORT)/service_OneKEa.qcow2 $(DIR_EXPORT)/service_OneKE_storage.qcow2
	@$(INFO) "Packer service_OneKEa done"

packer-service_Ray: PKR_VAR_nvidia_driver_path := $(NVIDIA_DRIVER_PATH)
packer-service_Ray: packer-ubuntu2404 $(DIR_EXPORT)/service_Ray.qcow2
	@$(INFO) "Packer service_Ray done"

packer-service_Ray.aarch64: PKR_VAR_nvidia_driver_path := $(NVIDIA_DRIVER_PATH)
packer-service_Ray.aarch64: packer-ubuntu2404.aarch64 $(DIR_EXPORT)/service_Ray.aarch64.qcow2
	@$(INFO) "Packer service_Ray.aarch64 done"

packer-service_Dynamo: PKR_VAR_nvidia_driver_path := $(NVIDIA_DRIVER_PATH)
packer-service_Dynamo: packer-ubuntu2404 $(DIR_EXPORT)/service_Dynamo.qcow2
	@$(INFO) "Packer service_Dynamo done"

packer-service_Dynamo.aarch64: PKR_VAR_nvidia_driver_path := $(NVIDIA_DRIVER_PATH)
packer-service_Dynamo.aarch64: packer-ubuntu2404.aarch64 $(DIR_EXPORT)/service_Dynamo.aarch64.qcow2
	@$(INFO) "Packer service_Dynamo done"

packer-service_Capi: packer-ubuntu2204 $(DIR_EXPORT)/service_Capi.qcow2
	@$(INFO) "Packer service_Capi done"

packer-service_Capi.aarch64: packer-ubuntu2204.aarch64 $(DIR_EXPORT)/service_Capi.aarch64.qcow2
	@$(INFO) "Packer service_Capi.aarch64 done"

packer-service_KaaS: packer-alpine321 $(DIR_EXPORT)/service_KaaS.qcow2
	@$(INFO) "Packer service_KaaS done"

packer-service_KaaS.aarch64: packer-alpine321.aarch64 $(DIR_EXPORT)/service_KaaS.aarch64.qcow2
	@$(INFO) "Packer service_KaaS.aarch64 done"

# run packer build for given distro or service
$(DIR_EXPORT)/service_OneKE_storage.qcow2:
	qemu-img create -f qcow2 $(DIR_EXPORT)/service_OneKE_storage.qcow2 10G
	@$(INFO) "Packer service_OneKE_storage done"

$(DIR_EXPORT)/%.qcow2: PREREQ_linux   := $(LINUX_CONTEXT_PACKAGES_FULL)
$(DIR_EXPORT)/%.qcow2: PREREQ_windows := $(WINDOWS_CONTEXT_PACKAGES_FULL)
$(DIR_EXPORT)/%.qcow2: $$(PREREQ_$$(or $$(findstring windows,$$*),linux))
	$(eval DISTRO_NAME := $(shell echo $* | sed 's/[0-9\.].*//'))
	$(eval DISTRO_VER  := $(shell echo $* | sed 's/^.[^0-9\.]*\(.*\)/\1/'))
	packer/build.sh '$(DISTRO_NAME)' '$(DISTRO_VER)' $@

# context packages
context-linux: $(LINUX_CONTEXT_PACKAGES_FULL)
	@$(INFO) "Generate context-linux done"

context-linux/out/%: $(CONTEXT_LINUX_SOURCES)
	cd context-linux/ && ./generate-all.sh

context-windows: $(WINDOWS_CONTEXT_PACKAGES_FULL)
	@$(INFO) "Generate context-windows done"

context-windows/out/%: $(CONTEXT_WINDOWS_SOURCES)
	cd context-windows/ && ./generate-all.sh

# context iso with all the context packages
context-iso: $(DIR_EXPORT)/one-context-$(VERSION)-$(RELEASE).iso
$(DIR_EXPORT)/one-context-$(VERSION)-$(RELEASE).iso: $(LINUX_CONTEXT_PACKAGES_FULL) $(WINDOWS_CONTEXT_PACKAGES_FULL)
	mkisofs -J -R -input-charset utf8 -m '*.iso' -V one-context-$(VERSION) -o $(DIR_EXPORT)/one-context.iso \
	context-linux/out/one-context?$(VERSION)* \
	context-windows/out/one-context-$(VERSION)*.msi

clean:
	-if [ -d '$(DIR_EXPORT)' ]; then rm -rf $(DIR_EXPORT)/*; fi
	-rm -rf context-linux/out/*
	-rm -rf context-windows/out/*

help:
	@echo 'Usage examples:'
	@echo '    make <distro>          -- build just one distro'
	@echo '    make <service>         -- build just one service'
	@echo
	@echo '    make distros-amd64     -- build all distros (x86_64)'
	@echo '    make distros-arm64     -- build all distros (aarch64)'
	@echo '    make services-amd64    -- build all services (x86_64)'
	@echo
	@echo '    make context-linux     -- build context linux packages'
	@echo '    make context-windows   -- build windows linux packages'
	@echo
	@echo 'Available distros (x86_64):'
	@echo "$(shell echo "$(DISTROS_AMD64)" | fmt -w 65 | tr '\n' '\1' )" \
		           | tr '\1' '\n' | sed 's/^/    /'
	@echo 'Available distros (aarch64):'
	@echo "$(shell echo "$(DISTROS_ARM64)" | fmt -w 65 | tr '\n' '\1' )" \
		           | tr '\1' '\n' | sed 's/^/    /'
	@echo 'Available services (x86_64):'
	@echo "$(shell echo "$(SERVICES_AMD64)" | fmt -w 65 | tr '\n' '\1' )" \
		           | tr '\1' '\n' | sed 's/^/    /'
	@echo 'Available services (aarch64):'
	@echo '    $(SERVICES_ARM64)'
	@echo
	@echo 'Available Windows (x86_64):'
	@echo '    $(wordlist 1,2,$(WINDOWS)) ... (see Makefile.config)'

version:
	@echo $(VERSION)-$(RELEASE) > version
