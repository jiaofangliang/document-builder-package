COMPANY_NAME ?= onlyoffice
PRODUCT_NAME ?= documentbuilder
PRODUCT_VERSION ?= 0.0.0
BUILD_NUMBER ?= 0
PACKAGE_NAME := $(COMPANY_NAME)-$(PRODUCT_NAME)
PACKAGE_VERSION := $(PRODUCT_VERSION)-$(BUILD_NUMBER)

UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),x86_64)
	RPM_ARCH := x86_64
	DEB_ARCH := amd64
	WIN_ARCH := x64
endif
ifneq ($(filter %86,$(UNAME_M)),)
	RPM_ARCH := i386
	DEB_ARCH := i386
	WIN_ARCH := x86
endif

RPM_BUILD_DIR := $(PWD)/rpm/builddir
DEB_BUILD_DIR := $(PWD)/deb
EXE_BUILD_DIR = $(PWD)/exe

RPM_PACKAGE_DIR := $(RPM_BUILD_DIR)/RPMS/$(RPM_ARCH)
DEB_PACKAGE_DIR := $(DEB_BUILD_DIR)

DEB_REPO := $(PWD)/repo
RPM_REPO := $(PWD)/repo-rpm

DEB_REPO_DATA := $(DEB_REPO)/Packages.gz
RPM_REPO_DATA := $(RPM_REPO)/repodata

EXE_REPO := repo-exe
EXE_REPO_DATA := $(EXE_REPO)/$(PACKAGE_NAME)-$(PRODUCT_VERSION).$(BUILD_NUMBER)-$(WIN_ARCH).exe

RPM_REPO_OS_NAME := centos
RPM_REPO_OS_VER := 7
RPM_REPO_DIR := $(RPM_REPO_OS_NAME)/$(RPM_REPO_OS_VER)

DEB_REPO_OS_NAME := ubuntu
DEB_REPO_OS_VER := trusty
DEB_REPO_DIR := $(DEB_REPO_OS_NAME)/$(DEB_REPO_OS_VER)

EXE_REPO_DIR = windows

RPM := $(RPM_PACKAGE_DIR)/$(PACKAGE_NAME)-$(PACKAGE_VERSION).$(RPM_ARCH).rpm
DEB := $(DEB_PACKAGE_DIR)/$(PACKAGE_NAME)_$(PACKAGE_VERSION)_$(DEB_ARCH).deb
EXE := $(EXE_BUILD_DIR)/$(PACKAGE_NAME)-$(PRODUCT_VERSION).$(BUILD_NUMBER)-$(WIN_ARCH).exe

ifeq ($(OS),Windows_NT)
	PLATFORM := win
	EXEC_EXT := .exe
	SHELL_EXT := .bat
	SHARED_EXT := .dll
	DEPLOY := $(EXE_REPO_DATA)
else
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		PLATFORM := linux
		SHARED_EXT := .so*
		SHELL_EXT := .sh
		DEPLOY := $(RPM_REPO_DATA) $(DEB_REPO_DATA)
	endif
endif

MKDIR := mkdir -p
RM := rm -rfv
CP := cp -rf -t
CD := cd
CURL := curl -L -o

ifeq ($(WIN_ARCH),x64)
ISCC := iscc //Qp //S"byparam=signtool.exe sign /v /s My /n Ascensio /t http://timestamp.verisign.com/scripts/timstamp.dll \$$f"
else
ISCC := iscc //Qp /S"byparam=signtool.exe sign /v /s My /n Ascensio /t http://timestamp.verisign.com/scripts/timstamp.dll \$$f"
endif

CORE_PATH := ../core

SRC += ../$(PRODUCT_NAME)-$(PRODUCT_VERSION)/*

DEST := common/$(PRODUCT_NAME)/home

VCREDIST := exe/res/vcredist_$(WIN_ARCH).exe

.PHONY: all clean deb rpm exe deploy

all: deb rpm

rpm: $(RPM)

deb: $(DEB)

exe: $(EXE)

clean:
	$(RM) $(DEB_PACKAGE_DIR)/*.deb\
		$(DEB_PACKAGE_DIR)/*.changes\
		$(RPM_BUILD_DIR)\
		$(EXE_BUILD_DIR)/*.exe\
		$(VCREDIST)\
		$(DEB_REPO)\
		$(RPM_REPO)\
		$(EXE_REPO)\
		$(PRODUCT_NAME)

$(PRODUCT_NAME):
	$(MKDIR) $(DEST)
	$(CP) $(DEST) $(SRC)

	echo "Done" > $@

$(RPM):	$(PRODUCT_NAME)
	sed 's/{{PRODUCT_VERSION}}/'$(PRODUCT_VERSION)'/'  -i rpm/$(PACKAGE_NAME).spec
	sed 's/{{BUILD_NUMBER}}/'${BUILD_NUMBER}'/'  -i rpm/$(PACKAGE_NAME).spec
	sed 's/{{BUILD_ARCH}}/'${RPM_ARCH}'/'  -i rpm/$(PACKAGE_NAME).spec

	$(CD) rpm && rpmbuild -bb --define "_topdir $(RPM_BUILD_DIR)" $(PACKAGE_NAME).spec

$(DEB): $(PRODUCT_NAME)
	sed 's/{{PACKAGE_VERSION}}/'$(PACKAGE_VERSION)'/'  -i deb/$(PACKAGE_NAME)/debian/changelog
	sed "s/{{BUILD_ARCH}}/"$(DEB_ARCH)"/"  -i deb/$(PACKAGE_NAME)/debian/control

	$(CD) deb/$(PACKAGE_NAME) && dpkg-buildpackage -b -uc -us

$(EXE): $(VCREDIST)
	sed "s/"{{PRODUCT_VERSION}}"/"$(PRODUCT_VERSION)"/" -i exe/common.iss
	sed "s/"{{BUILD_NUMBER}}"/"$(BUILD_NUMBER)"/" -i exe/common.iss
	cd exe && $(ISCC) $(PACKAGE_NAME)-$(WIN_ARCH).iss

$(VCREDIST):
	$(CURL) $(VCREDIST) http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_$(WIN_ARCH).exe

$(RPM_REPO_DATA): $(RPM)
	$(RM) $(RPM_REPO)
	$(MKDIR) $(RPM_REPO)

	$(CP) $(RPM_REPO) $(RPM)
	createrepo -v $(RPM_REPO)

	aws s3 sync \
		$(RPM_REPO) \
		s3://repo-doc-onlyoffice-com/$(RPM_REPO_DIR)/$(PACKAGE_NAME)/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(RPM_ARCH)/ \
		--acl public-read --delete

	aws s3 sync \
		s3://repo-doc-onlyoffice-com/$(RPM_REPO_DIR)/$(PACKAGE_NAME)/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(RPM_ARCH)/  \
		s3://repo-doc-onlyoffice-com/$(RPM_REPO_DIR)/$(PACKAGE_NAME)/$(GIT_BRANCH)/latest/$(RPM_ARCH)/ \
		--acl public-read --delete

$(DEB_REPO_DATA): $(DEB)
	$(RM) $(DEB_REPO)
	$(MKDIR) $(DEB_REPO)

	$(CP) $(DEB_REPO) $(DEB)
	dpkg-scanpackages -m repo /dev/null | gzip -9c > $(DEB_REPO_DATA)

	aws s3 sync \
		$(DEB_REPO) \
		s3://repo-doc-onlyoffice-com/$(DEB_REPO_DIR)/$(PACKAGE_NAME)/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(DEB_ARCH)/repo \
		--acl public-read --delete

	aws s3 sync \
		s3://repo-doc-onlyoffice-com/$(DEB_REPO_DIR)/$(PACKAGE_NAME)/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(DEB_ARCH)/repo \
		s3://repo-doc-onlyoffice-com/$(DEB_REPO_DIR)/$(PACKAGE_NAME)/$(GIT_BRANCH)/latest/$(DEB_ARCH)/repo \
		--acl public-read --delete

$(EXE_REPO_DATA): $(EXE)
	rm -rfv $(EXE_REPO)
	mkdir -p $(EXE_REPO)

	cp -rv $(EXE) $(EXE_REPO);

	aws s3 sync \
		$(EXE_REPO) \
		s3://repo-doc-onlyoffice-com/$(EXE_REPO_DIR)/$(PACKAGE_NAME)/$(GIT_BRANCH)/$(PRODUCT_VERSION).$(BUILD_NUMBER)/$(WIN_ARCH)/ \
		--acl public-read --delete

	aws s3 sync \
		s3://repo-doc-onlyoffice-com/$(EXE_REPO_DIR)/$(PACKAGE_NAME)/$(GIT_BRANCH)/$(PRODUCT_VERSION).$(BUILD_NUMBER)/$(WIN_ARCH)/  \
		s3://repo-doc-onlyoffice-com/$(EXE_REPO_DIR)/$(PACKAGE_NAME)/$(GIT_BRANCH)/latest/$(WIN_ARCH)/ \
		--acl public-read --delete

deploy: $(DEPLOY)
