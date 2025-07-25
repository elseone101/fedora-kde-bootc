# NOTICE
This fork was created in order to PR certain changes to upstream. The changes are in the other branch `upstream-improvements`.
The branch you are viewing is abandoned, and incompletely modified.

# (Name TBD)
The motivation for this project is inspired by the increasing popularity of atomic distros as technology advances. The Fedora project is one of the leaders in bringing this concept to the public, with other projects following suit. This approach offers significant benefits in terms of stability and security.

They apply updates as a single transaction, known as atomic upgrades, which means if an update doesn't work as expected, the system can instantly roll back to its last stable state, saving users from potential issues. The immutable nature of the filesystem components reduces the risk of system corruption and unauthorised modifications as the core system files are read-only, making them impossible to modify.

If you are planning to spin off various instances from the same image (e.g. setting up computers for members of your family or work), atomic distros provide a reliable desktop experience where every instance of the desktop is consistent with each other, reducing discrepancies in software versions and behaviour.

Mainstream sources like Fedora and Universal Blue offer various atomic desktops with curated configurations and package selections for the average user. But what if you're ready to take control of your desktop and customise it entirely, from packages and configurations to firewall, DNS, and update schedules?

Thanks to bootc and the associated tools, building a personalised desktop experience is no longer difficult. This project aims to provide you with basic tips to help you customise your desktop. This is not a final product, but the means and steps to build your own.

## What is bootc?
Using existing container building techniques, bootc allows you to build your own OS. Container images adhere to the OCI specification and utilise container tools for building and transporting your containers. Once installed on a node, the container functions as a regular OS.

The container image includes a Linux kernel (e.g., in `/usr/lib/modules`) for booting. Bootc includes a package manager, allowing you to scrutinise installed and available packages from existing and added repositories. Additionally, using `bootc usr-overlay`, bootc mounts an overlay on `/usr`, enabling temporary package installation via `dnf` for testing purposes.

The filesystem structure follows ostree specifications:

- The `/usr` (as well as `/opt`) directory is read-only, with all changes managed by the container image.
- The `/etc` directory is editable, but any changes applied in the container image will be transferred to the node unless the file was modified locally.
- Changes to `/var` (including `/var/home`) are made during the first boot. Afterwards, `/var` remains untouched.

The full documentation for bootc can be found here: https://bootc-dev.github.io/bootc/

## What is kde-bootc?
This project utilises `quay.io/fedora/fedora-kinoite` as the base image to create a customizable container for building your personalised Fedora KDE atomic desktop. 

The aim is to explain basic concepts and share some useful tips. It is important to note that this template is meant to be modified according to your needs, so it is not necessarily a final product. However, it will work out of the box.

Although it is tailored to KDE Plasma, most of the concepts and methodologies also apply to other desktop environments.

(`quay.io/fedora/fedora-bootc` is the "generic" base image without any DE, `quay.io/organization/fedora` is where all their images exist)

## sysext-manager
[sysext-manager](https://github.com/travier/sysexts-manager) is a powerful tool used in order to manage the installed sysexts.
The sysexts it manages are from a curated collection [fedora-sysexts](https://extensions.fcos.fr/).

The collection contains common non-essential software like libvirt, fd-find, erofs-utils, which you can add to your system easily, without using `rpm-ostree` or yet another container build.
(Kindly refer the linked sites themselves for usage info)

## Repository structure
(Will be refactored)
I tried to organise the repository for easy reading and maintenance. Files are stored in functional and well-defined directories, making them easy to find and understand their purpose and where they will be placed in the container image. 

Each file follows a specific naming convention. For instance a file `/usr/lib/credstore/home.create.admin` is named as `usr__lib__credstore__home.create.admin`

**Folders:**
- *.github*: Contains an example of GitHub action to build the container and publish the image
- *scripts*: Contains scripts to be ran from the Containerfile during building
- *system*: Contains files to be copied to `/usr` and `/etc`
- *systemd*: Contains systemd unit files to be copied to `/usr/lib/systemd`

## Explaining the Containerfile step by step
### Image base
The `fedora-bootc` project is part of the Cloud Native Computing Foundation (CNCF) Sandbox projects and  generates reference "base images" of bootable containers designed for use with the bootc project. `fedora-kinoite` is based off it with KDE included.
```
FROM quay.io/fedora/fedora-kinoite
```
### Setup filesystem
`/opt` is a directory where software is installed when it isn't cleanly organized as it should be in `/usr`. Writable files are linked to equivalents in `/var/opt`.
In order to keep `/opt` seamless with `/usr`, it is linked to `/usr/opt`
```
RUN <<EOOPT
mkdir /usr/opt
[ -d /opt ] && mv /opt/* /usr/opt
rm -f /opt
ln -sf usr/opt /opt
EOOPT
```
In some cases, for successful package installation the `/var/roothome` directory must exist. If this folder is missing, the container build may fail. It is advisable to create this directory before installing packages.
```
RUN mkdir /var/roothome
```
### Prepare packages
To simplify the installation, and to have a record of installed and removed packages for future reference, I found useful keeping them as a resource under `/usr/share`. 
- All additional packages to be installed on top of *fedora-bootc* and the *KDE environment* are documented in `packages-added`. 
- Packages to be removed from *fedora-bootc* and the *KDE environment* are documented in `packages-removed`. 
- For convenience, the packages included in the base *fedora-bootc* are documented in `packages-fedora-bootc`.
```
COPY --chmod=0644 ./system/usr__local__share__kde-bootc__packages-removed /usr/local/share/kde-bootc/packages-removed
COPY --chmod=0644 ./system/usr__local__share__kde-bootc__packages-added /usr/local/share/kde-bootc/packages-added
RUN jq -r .packages[] /usr/share/rpm-ostree/treefile.json > /usr/local/share/kde-bootc/packages-fedora-bootc
```

### Install packages
For clarity and task separation, I divided the installation into two steps.

The installation of all other individual packages:
```
RUN grep -vE '^#' /usr/local/share/kde-bootc/packages-added | xargs dnf -y install –allowerasing
```
The script will select all lines not starting with `#` to be passed as arguments to `dnf -y install`. The `--allowerasing` option is necessary for cases like installing `vim-default-editor`, which would conflict with `nano-default-editor`, removing the latter first. 
This is one of the key files to modify to customise your installation.

AND downgrading the kernel (it simply enables kernel-install integration)
```
RUN dnf -y downgrade kernel
```

### Remove packages
This is an opportunity to remove software you may never use, saving resources and storage.
```
RUN grep -vE '^#' /usr/local/share/kde-bootc/packages-removed | xargs dnf -y remove
RUN dnf -y autoremove & dnf clean all
```
The criteria used in this project is summarised below:
- Remove packages that conflict with bootc and its immutable nature.
- Remove packages that bring unwanted dependencies, such as DNF4 and GTK3.
- Remove packages that handle deprecated services.
- Remove packages that are resource-heavy, or bring unnecessary services.

### Configuration
This section is designated for copying all necessary configuration files to `/usr` and `/etc`. As recommended by the *bootc project*, prioritise using `/usr` and use `/etc` as a fallback if needed.

Bash scripts that will be used by systemd services are stored in `/usr/local/bin`:
```
COPY --chmod=0755 ./system/usr__local__bin/* /usr/local/bin/
```
Custom configuration for new users' home directories will be added to `/etc/skel/`. This project adds `.bashrc.d/kde-bootc` to customise bash via this containerfile, and it can be tweaked as needed.
```
COPY --chmod=0644 ./system/etc__skel__kde-bootc /etc/skel/.bashrc.d/kde-bootc
```
If you're building your container image on GitHub and keeping it private, you'll need to create a **GITHUB_TOKEN** to download the image. Further information on [GitHub container registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry).

A **GITHUB_TOKEN** can be created from global settings under *Developer settings*. The only required scope for the token is `read:packages`, which will allow you to download your image.

Using this token, create the **GITHUB_CREDENTIAL** by generating a base64 output from your **GitHub USERNAME** and **GITHUB_TOKEN** combination: 
```
echo <GitHub USERNAME>:<GITHUB_TOKEN> | base64
```
The output must be added to `usr__lib__ostree__auth.json` file, which is copied to `/usr/lib/ostree/auth.json` for bootc to reference when downloading the image from your GitHub registry to update the system.
```
COPY --chmod=0600 ./system/usr__lib__ostree__auth.json /usr/lib/ostree/auth.json
```

### Systemd services
This service automates updates, replacing the default `bootc-fetch-apply-updates` service, which would download and apply updates as soon as they are available. This approach is problematic because it causes your computer to shut down without warning, so it is better to disable by masking it: 
```
RUN systemctl mask bootc-fetch-apply-updates.timer bootc-fetch-apply-updates.service
```
The replacement `bootc-fetch` service will download the image from the registry and queue it for the next reboot. It is enabled by default and can be turned on or off by the user as needed.
```
COPY --chmod=0644 ./systemd/usr__lib__systemd__system__bootc-fetch.service /usr/lib/systemd/system/bootc-fetch.service
COPY --chmod=0644 ./systemd/usr__lib__systemd__system__bootc-fetch.timer /usr/lib/systemd/system/bootc-fetch.timer
RUN systemctl enable bootc-fetch.timer
```
This systemd service in charge to update the bootloader is enabled by default. It will be triggered at boot.
```
RUN systemctl enable bootloader-update.service
```
### Clean and Checks
This section focuses on cleaning the container before converting it into an image.
```
RUN find /var/log -type f ! -empty -delete
RUN bootc container lint
```
## How to create an ISO?
Creating an ISO to install your *kde-bootc* desktop is simple. First, build the container image either on GitHub or locally. 

The instructions below will build the container locally, and ensure you do this as root so `bootc-image-builder` can use the image to make the ISO.
```
cd /path-to-your-repo
sudo podman build -t kde-bootc .
```
Then, outside the repository on a different directory, create a folder named `output` for the ISO image. Next, create the configuration file `config.toml` to be used by the installer with the content below to kick off a graphical installation:
```
[customizations.installer.kickstart]
contents = "graphical"
```

<!-- This isn't needed for now...
```
[customizations.installer.modules]
disable = [
  "org.fedoraproject.Anaconda.Modules.Users"
]
```
-->
<!-- So isn't this needed for now...
If you prefer a non-interactive text installation, you may use the variation below:
```
[customizations.installer.kickstart]
contents = """
text
clearpart --all --initlabel --disklabel=gpt
autopart --noswap
"""

[customizations.installer.modules]
disable = [
  "org.fedoraproject.Anaconda.Modules.Users"
]
```
The latter will setup systemd default target to `multi-user.target`, so you will need to run `systemctl set-default graphical.target` to boot into a graphical environment.
In both configurations, the user module is disabled. We do not need to set up a user during installation, as this is already being taken care of.
-->

Within the directory where `./output/` and `./config.toml` exists, run `bootc-image-builder` utility which is available as a container. It must be ran as root.
```
sudo podman run --rm -it --privileged --pull=newer \
--security-opt label=type:unconfined_t \
-v ./output:/output \
-v /var/lib/containers/storage:/var/lib/containers/storage \
-v ./config.toml:/config.toml:ro \
quay.io/centos-bootc/bootc-image-builder:latest \
--type iso \
--chown 1000:1000 \
localhost/kde-bootc
```
If everything goes well, the ISO image will be available in the `./output/` directory.

For more information on `bootc-image-builder`, visit: https://github.com/osbuild/bootc-image-builder
## Post installation
Once *kde-bootc* is installed, there are additional settings to improve usability. 

If your computer has a fingerprint reader, setting it up is not possible from Plasma's user settings, as `systemd-homed` is not yet recognised by the desktop. However, you can manually enrol your fingerprint by running `fprintd-enroll` and placing your finger on the reader as you normally would. 
```
sudo fprintd-enroll admin
```
Same as above, you cannot set up the avatar from Plasma's user settings, but you can copy an available avatar (PNG file) from Plasma's avatar directory to the account service's directory. Ensure it is named the same as the username: 
```
/usr/share/plasma/avatars/<avatar.png> -> /var/lib/AccountsService/icons/admin
```

To pull your image from a private GitHub repository using podman, copy `/usr/lib/ostree/auth.json` to `/home/admin/.config/containers/auth.json` for user space, and `/root/.config/containers/auth.json` for root. It will allow you to use `podman pull ..` and `sudo podman pull ..` respectively.
## Troubleshooting
### Drifts on `/etc`
Please note that a configuration file in `/etc` drifts when it is modified locally. Consequently, bootc will no longer manage this file, and new releases won't be transferred to your installation. While this might be desired in some cases, it can also lead to issues. 

For instance, if `/etc/passwd` is locally modified, `uid` or `gid` allocations for services may not get updated, resulting in service failures. Also, if you have installed packages using `bootc usr-overlay`, it is advisable to remove them before unmounting `/usr` to ensure any configuration files in `/etc` are also removed.

Use `ostree admin config-diff` to list the files in your local `/etc` that are no longer managed by bootc, because they are modified or added.

If a particular configuration file needs to be managed by bootc, you can revert it by copying the version created by the container build from `/usr/etc` to `/etc`.
### Adding packages after first installation
The `/var` directory is populated in the container image and transferred to your OS during initial installation. Subsequent updates to the container image will not affect `/var`. This is the expected behavior of bootc and generally works fine. However, some RPM packages execute scriptlets after installation, resulting in changes to `/var` that will not be transferred to your OS.

Instead of trying to identify and update the missing bits in `/var`, I found it easier to overlay `/usr` and reinstall the packages after updating and rebooting bootc.
```
--> Add your packages to: usr__local__share__kde-bootc__packages-added, update bootc and reboot

# Overlay /usr
sudo bootc usr-overlay

# Reinstall the package(s), so scriptlets can run and sort out /var
sudo dnf reinstall <packages>

# Remove /usr overlay
sudo reboot
```
