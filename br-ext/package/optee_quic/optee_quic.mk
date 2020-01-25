OPTEE_QUIC_VERSION = 1.0
OPTEE_QUIC_SOURCE = local
OPTEE_QUIC_SITE = $(BR2_PACKAGE_OPTEE_QUIC_SITE)
OPTEE_QUIC_SITE_METHOD = local
OPTEE_QUIC_INSTALL_STAGING = YES
OPTEE_QUIC_DEPENDENCIES = optee_client host-python-pycrypto
OPTEE_QUIC_SDK = $(BR2_PACKAGE_OPTEE_QUIC_SDK)
OPTEE_QUIC_CONF_OPTS = -DOPTEE_QUIC_SDK=$(OPTEE_QUIC_SDK)

define OPTEE_QUIC_BUILD_TAS
	@for f in $(@D)/*/ta/Makefile; \
	do \
	  echo Building $$f && \
			$(MAKE) CROSS_COMPILE="$(shell echo $(BR2_PACKAGE_OPTEE_QUIC_CROSS_COMPILE))" \
			O=out TA_DEV_KIT_DIR=$(OPTEE_QUIC_SDK) \
			$(TARGET_CONFIGURE_OPTS) -C $${f%/*} all; \
	done
endef

define OPTEE_QUIC_INSTALL_TAS
	@$(foreach f,$(wildcard $(@D)/*/ta/out/*.ta), \
		mkdir -p $(TARGET_DIR)/lib/optee_armtz && \
		$(INSTALL) -v -p  --mode=444 \
			--target-directory=$(TARGET_DIR)/lib/optee_armtz $f \
			&&) true
endef

OPTEE_QUIC_POST_BUILD_HOOKS += OPTEE_QUIC_BUILD_TAS
OPTEE_QUIC_POST_INSTALL_TARGET_HOOKS += OPTEE_QUIC_INSTALL_TAS

$(eval $(cmake-package))
