COMPANY_NAME ?= ONLYOFFICE
PRODUCT_NAME ?= DocumentBuilder
COMPANY_NAME_LOW = $(shell echo $(COMPANY_NAME) | tr A-Z a-z)
PRODUCT_NAME_LOW = $(shell echo $(PRODUCT_NAME) | tr A-Z a-z)
PRODUCT_VERSION ?= 0.0.0
BUILD_NUMBER ?= 0
PACKAGE_NAME := $(COMPANY_NAME_LOW)-$(PRODUCT_NAME_LOW)
S3_BUCKET ?= repo-doc-onlyoffice-com

UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),x86_64)
	RPM_ARCH := x86_64
	DEB_ARCH := amd64
	WIN_ARCH := x64
	ARCH_SUFFIX := x64
	ARCHITECTURE := 64
endif
ifneq ($(filter %86,$(UNAME_M)),)
	RPM_ARCH := i386
	DEB_ARCH := i386
	WIN_ARCH := x86
	ARCH_SUFFIX := x86
	ARCHITECTURE := 32
endif

ifeq ($(OS),Windows_NT)
	PLATFORM := win
	EXEC_EXT := .exe
	SHELL_EXT := .bat
	SHARED_EXT := .dll
	ARCH_EXT := .zip
	SRC ?= ../build_tools/out/win_$(ARCHITECTURE)/$(COMPANY_NAME)/$(PRODUCT_NAME)/*
	PACKAGE_VERSION := $(PRODUCT_VERSION).$(BUILD_NUMBER)
else
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		PLATFORM := linux
		SHARED_EXT := .so*
		SHELL_EXT := .sh
		ARCH_EXT := .tar.gz
		SRC ?= ../build_tools/out/linux_$(ARCHITECTURE)/$(COMPANY_NAME_LOW)/$(PRODUCT_NAME_LOW)/*
		PACKAGE_VERSION := $(PRODUCT_VERSION)-$(BUILD_NUMBER)
	endif
endif

ARCH_REPO := $(PWD)/repo-arch
ARCH_REPO_DATA := $(ARCH_REPO)/$(PRODUCT_NAME_LOW)-$(PRODUCT_VERSION)-$(ARCH_SUFFIX)$(ARCH_EXT)
ARCH_PACKAGE_DIR := ..

RPM_BUILD_DIR := $(PWD)/rpm/builddir
DEB_BUILD_DIR := $(PWD)/deb
EXE_BUILD_DIR = exe

RPM_PACKAGE_DIR := $(RPM_BUILD_DIR)/RPMS/$(RPM_ARCH)
DEB_PACKAGE_DIR := $(DEB_BUILD_DIR)

REPO_NAME := repo
DEB_REPO := $(PWD)/$(REPO_NAME)
RPM_REPO := $(PWD)/repo-rpm

DEB_REPO_DATA := $(DEB_REPO)/Packages.gz
RPM_REPO_DATA := $(RPM_REPO)/repodata

EXE_REPO := repo-exe
EXE_REPO_DATA := $(EXE_REPO)/$(PACKAGE_NAME)-$(PACKAGE_VERSION)-$(WIN_ARCH).exe

RPM_REPO_OS_NAME := centos
RPM_REPO_OS_VER := 7
RPM_REPO_DIR := $(RPM_REPO_OS_NAME)/$(RPM_REPO_OS_VER)

DEB_REPO_OS_NAME := ubuntu
DEB_REPO_OS_VER := trusty
DEB_REPO_DIR := $(DEB_REPO_OS_NAME)/$(DEB_REPO_OS_VER)

EXE_REPO_DIR = windows

ARCH_REPO_DIR := linux

INDEX_HTML := index.html

ifeq ($(OS),Windows_NT)
  ARCH_REPO_DIR := $(EXE_REPO_DIR)
	DEPLOY := $(EXE_REPO_DATA) $(INDEX_HTML)
else
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		DEPLOY := $(RPM_REPO_DATA) $(DEB_REPO_DATA) $(INDEX_HTML)
	endif
endif

ARCHIVE := $(ARCH_PACKAGE_DIR)/$(PRODUCT_NAME_LOW)-$(PRODUCT_VERSION)-$(ARCH_SUFFIX)$(ARCH_EXT)
RPM := $(RPM_PACKAGE_DIR)/$(PACKAGE_NAME)-$(PACKAGE_VERSION).$(RPM_ARCH).rpm
DEB := $(DEB_PACKAGE_DIR)/$(PACKAGE_NAME)_$(PACKAGE_VERSION)_$(DEB_ARCH).deb
EXE := $(EXE_BUILD_DIR)/$(PACKAGE_NAME)-$(PACKAGE_VERSION)-$(WIN_ARCH).exe

MKDIR := mkdir -p
RM := rm -rfv
CP := cp -rf -t
CD := cd
CURL := curl -L -o

ISCC := iscc //Qp //S"byparam=signtool.exe sign /v /s My /n Ascensio /t http://timestamp.verisign.com/scripts/timstamp.dll \$$f"

CORE_PATH := ../core

DEST := common/$(PRODUCT_NAME_LOW)/home

ISXDL = $(EXE_BUILD_DIR)/scripts/isxdl/isxdl.dll

.PHONY: all clean deb rpm exe deploy

all: deb rpm arch

arch: $(ARCHIVE)

rpm: $(RPM)

deb: $(DEB)

exe: $(EXE)

clean:
	$(RM) $(DEB_PACKAGE_DIR)/*.deb\
		$(DEB_PACKAGE_DIR)/*.changes\
		$(RPM_BUILD_DIR)\
		$(EXE_BUILD_DIR)/*.exe\
		$(VCREDIST)\
		$(ARCH_PACKAGE_DIR)/*$(ARCH_EXT)\
		$(ARCH_REPO)\
		$(DEB_REPO)\
		$(RPM_REPO)\
		$(EXE_REPO)\
		$(INDEX_HTML)\
		$(PRODUCT_NAME_LOW)

$(PRODUCT_NAME_LOW):
	$(MKDIR) $(DEST)
	$(CP) $(DEST) $(SRC)

	echo "Done" > $@

$(RPM):	$(PRODUCT_NAME_LOW)
	sed 's/{{PRODUCT_VERSION}}/'$(PRODUCT_VERSION)'/'  -i rpm/$(PACKAGE_NAME).spec
	sed 's/{{BUILD_NUMBER}}/'${BUILD_NUMBER}'/'  -i rpm/$(PACKAGE_NAME).spec
	sed 's/{{BUILD_ARCH}}/'${RPM_ARCH}'/'  -i rpm/$(PACKAGE_NAME).spec

ifeq ($(RPM_ARCH),i386)
	sed 's/lib64/lib/'  -i rpm/$(PACKAGE_NAME).spec
endif

	$(CD) rpm && rpmbuild -bb --define "_topdir $(RPM_BUILD_DIR)" $(PACKAGE_NAME).spec

$(DEB): $(PRODUCT_NAME_LOW)
	sed 's/{{PACKAGE_VERSION}}/'$(PACKAGE_VERSION)'/'  -i deb/$(PACKAGE_NAME)/debian/changelog
	sed "s/{{BUILD_ARCH}}/"$(DEB_ARCH)"/"  -i deb/$(PACKAGE_NAME)/debian/control

	$(CD) deb/$(PACKAGE_NAME) && dpkg-buildpackage -b -uc -us

$(EXE): $(ISXDL)
	sed "s/"{{PRODUCT_VERSION}}"/"$(PRODUCT_VERSION)"/" -i exe/common.iss
	sed "s/"{{BUILD_NUMBER}}"/"$(BUILD_NUMBER)"/" -i exe/common.iss
	cd exe && $(ISCC) $(PACKAGE_NAME)-$(WIN_ARCH).iss

$(ISXDL):
	$(CURL) $(ISXDL) https://raw.githubusercontent.com/jrsoftware/ispack/master/isxdlfiles/isxdl.dll

$(RPM_REPO_DATA): $(RPM)
	$(RM) $(RPM_REPO)
	$(MKDIR) $(RPM_REPO)

	$(CP) $(RPM_REPO) $(RPM)
	createrepo -v $(RPM_REPO)

	aws s3 sync \
		$(RPM_REPO) \
		s3://repo-doc-onlyoffice-com/$(RPM_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(RPM_ARCH)/ \
		--acl public-read --delete

	aws s3 sync \
		s3://repo-doc-onlyoffice-com/$(RPM_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(RPM_ARCH)/  \
		s3://repo-doc-onlyoffice-com/$(RPM_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/latest/$(RPM_ARCH)/ \
		--acl public-read --delete

$(DEB_REPO_DATA): $(DEB)
	$(RM) $(DEB_REPO)
	$(MKDIR) $(DEB_REPO)

	$(CP) $(DEB_REPO) $(DEB)
	dpkg-scanpackages -m $(REPO_NAME) /dev/null | gzip -9c > $(DEB_REPO_DATA)

	aws s3 sync \
		$(DEB_REPO) \
		s3://repo-doc-onlyoffice-com/$(DEB_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(DEB_ARCH)/$(REPO_NAME) \
		--acl public-read --delete

	aws s3 sync \
		s3://repo-doc-onlyoffice-com/$(DEB_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(DEB_ARCH)/$(REPO_NAME) \
		s3://repo-doc-onlyoffice-com/$(DEB_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/latest/$(DEB_ARCH)/$(REPO_NAME) \
		--acl public-read --delete

$(EXE_REPO_DATA): $(EXE)
	rm -rfv $(EXE_REPO)
	mkdir -p $(EXE_REPO)

	cp -rv $(EXE) $(EXE_REPO);

	aws s3 sync \
		$(EXE_REPO) \
		s3://repo-doc-onlyoffice-com/$(EXE_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(WIN_ARCH)/ \
		--acl public-read --delete

	aws s3 sync \
		s3://repo-doc-onlyoffice-com/$(EXE_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(WIN_ARCH)/  \
		s3://repo-doc-onlyoffice-com/$(EXE_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/latest/$(WIN_ARCH)/ \
		--acl public-read --delete

$(ARCH_REPO_DATA): $(ARCHIVE)
	rm -rfv $(ARCH_REPO)
	mkdir -p $(ARCH_REPO)

	cp -rv $(ARCHIVE) $(ARCH_REPO)

	aws s3 sync \
		$(ARCH_REPO) \
		s3://repo-doc-onlyoffice-com/$(ARCH_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(ARCH_SUFFIX)/ \
		--acl public-read --delete

	aws s3 sync \
		s3://repo-doc-onlyoffice-com/$(ARCH_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(ARCH_SUFFIX)/  \
		s3://repo-doc-onlyoffice-com/$(ARCH_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/latest/$(ARCH_SUFFIX)/ \
		--acl public-read --delete

%-$(ARCH_SUFFIX).tar.gz : %
	tar -zcvf $@ $<

%-$(ARCH_SUFFIX).zip : %
	7z a -y $@ $<

M4_PARAMS += -D M4_S3_BUCKET=$(S3_BUCKET)

ifeq ($(OS),Windows_NT)
	M4_PARAMS += -D M4_EXE_URI="$(EXE_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(WIN_ARCH)/$(notdir $(EXE))"
else
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		M4_PARAMS += -D M4_DEB_URI="$(DEB_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(DEB_ARCH)/$(REPO_NAME)/$(notdir $(DEB))"
		M4_PARAMS += -D M4_RPM_URI="$(RPM_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(RPM_ARCH)/$(notdir $(RPM))"

	endif
endif

# M4_PARAMS += -D M4_ARCH_URI="$(ARCH_REPO_DIR)/$(PACKAGE_NAME)/origin/$(GIT_BRANCH)/$(PACKAGE_VERSION)/$(ARCH_SUFFIX)/$(notdir $(ARCHIVE))"

% : %.m4
	m4 $(M4_PARAMS)	$< > $@

deploy: $(DEPLOY)
