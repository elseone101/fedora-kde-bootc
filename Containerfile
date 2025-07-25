FROM quay.io/fedora/fedora-kinoite:42
MAINTAINER Pramod V U

# SETUP FILESYSTEM
RUN mkdir /var/roothome
RUN <<EOOPT
# Ensure /opt is read-only, manageable by bootc under /usr
mkdir /usr/opt
[ -d /opt ] && mv /opt/* /usr/opt
rm -f /opt
ln -sf usr/opt /opt
EOOPT

# PREPARE PACKAGES
COPY --chmod=0644 ./system/usr__local__share__kde-bootc__packages-removed /usr/local/share/kde-bootc/packages-removed
COPY --chmod=0644 ./system/usr__local__share__kde-bootc__packages-added /usr/local/share/kde-bootc/packages-added
RUN jq -r .packages[] /usr/share/rpm-ostree/treefile.json > /usr/local/share/kde-bootc/packages-fedora-bootc

# Install commonly used plugins
RUN dnf -y install dnf5-plugins

# (If) This is much different from upstream fedora
#RUN dnf -y swap fedora-release generic-release

# INSTALL PACKAGES
RUN grep -vE '^#' /usr/local/share/kde-bootc/packages-added | xargs dnf -y install --allowerasing

# ENABLE kernel-install INTEGRATION
RUN dnf -y downgrade kernel
# cf. https://docs.fedoraproject.org/en-US/bootc/building-containers/#_kernel_management

# REMOVE PACKAGES
RUN grep -vE '^#' /usr/local/share/kde-bootc/packages-removed | xargs dnf -y remove
RUN dnf -y autoremove && dnf clean all

# CONFIGURATION
COPY --chmod=0600 ./system/usr__lib__ostree__auth.json /usr/lib/ostree/auth.json

# SYSTEMD
COPY --chmod=0644 ./systemd/usr__lib__systemd__system__bootc-fetch.service /usr/lib/systemd/system/bootc-fetch.service
COPY --chmod=0644 ./systemd/usr__lib__systemd__system__bootc-fetch.timer /usr/lib/systemd/system/bootc-fetch.timer

RUN systemctl enable bootloader-update.service
RUN systemctl mask bootc-fetch-apply-updates.timer

# CLEAN & CHECK
RUN find /var/log -type f ! -empty -delete
RUN bootc container lint
