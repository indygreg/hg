$(eval HGROOT := $(shell cd ../..; pwd))

DEBIAN_CODENAMES := \
  jessie \
  stretch \
  buster

UBUNTU_CODENAMES := \
  trusty \
  xenial \
  artful \
  bionic \

FEDORA_RELEASES := \
  20 \
  21

CENTOS_RELEASES := \
  5 \
  6 \
  7

# Build a Python for these CentOS releases.
CENTOS_WITH_PYTHON_RELEASES := 5 6

help:
	@echo 'Packaging Make Targets'
	@echo ''
	@echo 'docker-centos-{$(strip $(CENTOS_RELEASES))}'
	@echo '   Build an RPM for a specific CentOS version using Docker.'
	@echo ''
	@echo 'docker-debian-{$(strip $(DEBIAN_CODENAMES))}'
	@echo '   Build Debian packages specific to a Debian distro using Docker.'
	@echo ''
	@echo 'docker-fedora-{$(strip $(FEDORA_RELEASES))}'
	@echo '   Build an RPM for a specific Fedora version using Docker.'
	@echo ''
	@echo 'docker-ubuntu-{$(strip $(UBUNTU_CODENAMES))}'
	@echo '   Build Debian package specific to an Ubuntu distro using Docker.'
	@echo ''
	@echo 'docker-ubuntu-{$(strip $(UBUNTU_CODENAMES))}-ppa'
	@echo '   Build a source-only Debian package specific to an Ubuntu distro'
	@echo '   using Docker.'
	@echo ''
	@echo 'linux-wheels'
	@echo '   Build Linux manylinux wheels using Docker.'
	@echo ''
	@echo 'linux-wheels-{x86_64, i686}'
	@echo '   Build Linux manylinux wheels for a specific architecture using Docker'
	@echo ''
	@echo 'deb'
	@echo '   Build a Debian package locally targeting the current system'
	@echo ''
	@echo 'ppa'
	@echo '   Build a Debian source package locally targeting the current system'
	@echo ''
	@echo 'centos-{$(strip $(CENTOS_RELEASES))}'
	@echo '   Build an RPM for a specific CentOS version locally'
	@echo ''
	@echo 'fedora-{$(strip $(FEDORA_RELEASES))}'
	@echo '   Build an RPM for a specific Fedora version locally'

.PHONY: help

.PHONY: deb
deb:
	./builddeb

.PHONY: ppa
ppa:
	./builddeb --source-only

# Debian targets.
define debian_targets =
.PHONY: docker-debian-$(1)
docker-debian-$(1):
	./dockerdeb debian $(1)

endef

$(foreach codename,$(DEBIAN_CODENAMES),$(eval $(call debian_targets,$(codename))))

# Ubuntu targets.
define ubuntu_targets =
.PHONY: docker-ubuntu-$(1)
docker-ubuntu-$(1):
	./dockerdeb ubuntu $(1)

.PHONY: docker-ubuntu-$(1)-ppa
docker-ubuntu-$(1)-ppa:
	./dockerdeb ubuntu $(1) --source-only

endef

$(foreach codename,$(UBUNTU_CODENAMES),$(eval $(call ubuntu_targets,$(codename))))

# Fedora targets.
define fedora_targets
.PHONY: fedora$(1)
fedora$(1):
	mkdir -p $$(HGROOT)/packages/fedora$(1)
	./buildrpm
	cp $$(HGROOT)/rpmbuild/RPMS/*/* $$(HGROOT)/packages/fedora$(1)
	cp $$(HGROOT)/rpmbuild/SRPMS/* $$(HGROOT)/packages/fedora$(1)
	rm -rf $(HGROOT)/rpmbuild

.PHONY: docker-fedora$(1)
docker-fedora$(1):
	mkdir -p $$(HGROOT)/packages/fedora($1)
	./dockerrpm fedora$(1)

endef

$(foreach release,$(FEDORA_RELEASES),$(eval $(call fedora_targets,$(release))))

# CentOS targets.
define centos_targets
.PHONY: centos$(1)
centos$(1):
	mkdir -p $$(HGROOT)/packages/centos$(1)
	./buildrpm $$(if $$(filter $(1),$$(CENTOS_WITH_PYTHON_RELEASES)),--withpython)
	cp $$(HGROOT)/rpmbuild/RPMS/*/* $$(HGROOT)/packages/centos$(1)
	cp $$(HGROOT)/rpmbuild/SRPMS/* $$(HGROOT)/packages/centos$(1)

.PHONY: docker-centos$(1)
docker-centos$(1):
	mkdir -p $$(HGROOT)/packages/centos$(1)
	./dockerrpm centos$(1) $$(if $$(filter $(1),$$(CENTOS_WITH_PYTHON_RELEASES)),--withpython)

endef

$(foreach release,$(CENTOS_RELEASES),$(eval $(call centos_targets,$(release))))

.PHONY: linux-wheels
linux-wheels: linux-wheels-x86_64 linux-wheels-i686

.PHONY: linux-wheels-x86_64
linux-wheels-x86_64:
	docker run -e "HGTEST_JOBS=$(shell nproc)" --rm -ti -v `pwd`/../..:/src quay.io/pypa/manylinux1_x86_64 /src/contrib/packaging/build-linux-wheels.sh

.PHONY: linux-wheels-i686
linux-wheels-i686:
	docker run -e "HGTEST_JOBS=$(shell nproc)" --rm -ti -v `pwd`/../..:/src quay.io/pypa/manylinux1_i686 linux32 /src/contrib/packaging/build-linux-wheels.sh
