$(eval HGROOT := $(shell cd ../..; pwd))

help:
	@echo 'Packaging Make Targets'
	@echo ''
	@echo 'docker-centos-{5, 6, 7}'
	@echo '   Build an RPM for a specific CentOS version using Docker.'
	@echo ''
	@echo 'docker-debian-{jessie, stretch}'
	@echo '   Build Debian packages specific to a Debian distro using Docker.'
	@echo ''
	@echo 'docker-fedora-{20, 21}'
	@echo '   Build an RPM for a specific Fedora version using Docker.'
	@echo ''
	@echo 'docker-ubuntu-{trusty, xenial, artful, bionic}'
	@echo '   Build Debian package specific to an Ubuntu distro using Docker.'
	@echo ''
	@echo 'docker-ubuntu-{trusty, xenial, artful, bionic}-ppa'
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
	@echo 'centos-{5, 6, 7}'
	@echo '   Build an RPM for a specific CentOS version locally'
	@echo ''
	@echo 'fedora-{20, 21}'
	@echo '   Build an RPM for a specific Fedora version locally'

.PHONY: help

.PHONY: deb
deb:
	./builddeb

.PHONY: ppa
ppa:
	./builddeb --source-only

docker/debian-%: docker/debian.template
	sed "s/__CODENAME__/$*/" $< > $@

.PHONY: docker-debian-jessie
docker-debian-jessie: docker/debian-jessie
	./dockerdeb debian jessie

.PHONY: docker-debian-stretch
docker-debian-stretch: docker/debian-stretch
	./dockerdeb debian stretch

docker/ubuntu-%: docker/ubuntu.template
	sed "s/__CODENAME__/$*/" $< > $@

.PHONY: docker-ubuntu-trusty
docker-ubuntu-trusty: docker/ubuntu-trusty
	./dockerdeb ubuntu trusty

.PHONY: docker-ubuntu-trusty-ppa
docker-ubuntu-trusty-ppa: docker/ubuntu-trusty
	./dockerdeb ubuntu trusty --source-only

.PHONY: docker-ubuntu-xenial
docker-ubuntu-xenial: docker/ubuntu-xenial
	./dockerdeb ubuntu xenial

.PHONY: docker-ubuntu-xenial-ppa
docker-ubuntu-xenial-ppa: docker/ubuntu-xenial
	./dockerdeb ubuntu xenial --source-only

.PHONY: docker-ubuntu-artful
docker-ubuntu-artful: docker/ubuntu-artful
	./dockerdeb ubuntu artful

.PHONY: docker-ubuntu-artful-ppa
docker-ubuntu-artful-ppa: docker/ubuntu-artful
	./dockerdeb ubuntu artful --source-only

.PHONY: docker-ubuntu-bionic
docker-ubuntu-bionic: docker/ubuntu-bionic
	./dockerdeb ubuntu bionic

.PHONY: docker-ubuntu-bionic-ppa
docker-ubuntu-bionic-ppa: docker/ubuntu-bionic
	./dockerdeb ubuntu bionic --source-only

.PHONY: fedora20
fedora20:
	mkdir -p $(HGROOT)/packages/fedora20
	./buildrpm
	cp $(HGROOT)/rpmbuild/RPMS/*/* $(HGROOT)/packages/fedora20
	cp $(HGROOT)/rpmbuild/SRPMS/* $(HGROOT)/packages/fedora20
	rm -rf $(HGROOT)/rpmbuild

.PHONY: docker-fedora20
docker-fedora20:
	mkdir -p $(HGROOT)/packages/fedora20
	./dockerrpm fedora20

.PHONY: fedora21
fedora21:
	mkdir -p $(HGROOT)/packages/fedora21
	./buildrpm
	cp $(HGROOT)/rpmbuild/RPMS/*/* $(HGROOT)/packages/fedora21
	cp $(HGROOT)/rpmbuild/SRPMS/* $(HGROOT)/packages/fedora21
	rm -rf $(HGROOT)/rpmbuild

.PHONY: docker-fedora21
docker-fedora21:
	mkdir -p $(HGROOT)packages/fedora21
	./dockerrpm fedora21

.PHONY: centos5
centos5:
	mkdir -p $(HGROOT)/packages/centos5
	./buildrpm --withpython
	cp $(HGROOT)/rpmbuild/RPMS/*/* $(HGROOT)/packages/centos5
	cp $(HGROOT)/rpmbuild/SRPMS/* $(HGROOT)/packages/centos5

.PHONY: docker-centos5
docker-centos5:
	mkdir -p $(HGROOT)/packages/centos5
	./dockerrpm centos5 --withpython

.PHONY: centos6
centos6:
	mkdir -p $(HGROOT)/packages/centos6
	./buildrpm --withpython
	cp $(HGROOT)/rpmbuild/RPMS/*/* $(HGROOT)/packages/centos6
	cp $(HGROOT)/rpmbuild/SRPMS/* $(HGROOT)/packages/centos6

.PHONY: docker-centos6
docker-centos6:
	mkdir -p $(HGROOT)/packages/centos6
	./dockerrpm centos6 --withpython

.PHONY: centos7
centos7:
	mkdir -p $(HGROOT)/packages/centos7
	./buildrpm
	cp $(HGROOT)/rpmbuild/RPMS/*/* $(HGROOT)/packages/centos7
	cp $(HGROOT)/rpmbuild/SRPMS/* $(HGROOT)/packages/centos7

.PHONY: docker-centos7
docker-centos7:
	mkdir -p $(HGROOT)/packages/centos7
	./dockerrpm centos7

.PHONY: linux-wheels
linux-wheels: linux-wheels-x86_64 linux-wheels-i686

.PHONY: linux-wheels-x86_64
linux-wheels-x86_64:
	docker run -e "HGTEST_JOBS=$(shell nproc)" --rm -ti -v `pwd`/../..:/src quay.io/pypa/manylinux1_x86_64 /src/contrib/packaging/build-linux-wheels.sh

.PHONY: linux-wheels-i686
linux-wheels-i686:
	docker run -e "HGTEST_JOBS=$(shell nproc)" --rm -ti -v `pwd`/../..:/src quay.io/pypa/manylinux1_i686 linux32 /src/contrib/packaging/build-linux-wheels.sh
