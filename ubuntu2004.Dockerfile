FROM ubuntu:20.04

# Set username, password, uid and guid
ARG USERNAME=vscode
ARG PASSWORD=vscode
ARG CONAN_VERSION=1.49.0
ARG USER_UID=1001
ARG USER_GID=$USER_UID
ENV HOME=/home/${USERNAME}
ENV DOCKER_BUILDKIT=1

# Config shell
ARG INSTALL_ZSH="true"

USER root

# Install needed packages and setup non-root user. Use a separate RUN statement to add your own dependencies.
# git-flow-debian.sh from https://github.com/petervanderdoes/gitflow-avh
COPY script-library/common-debian.sh \
    script-library/git-lfs-debian.sh \
    script-library/git-flow-debian.sh \
    script-library/docker-in-docker-debian.sh \
    /tmp/library-scripts/

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && bash /tmp/library-scripts/common-debian.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" \
    && if [ "$INSTALL_ZSH" = "true" ]; then usermod --shell /bin/zsh ${USERNAME}; fi \
    && bash /tmp/library-scripts/git-lfs-debian.sh \
    && /bin/bash /tmp/library-scripts/docker-in-docker-debian.sh \
    && bash /tmp/library-scripts/git-flow-debian.sh "/usr/local" "gitflow" "https://github.com/petervanderdoes/gitflow-avh.git" "install" "stable" \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts 

# Set up folders for vscode workspaces, extensions/pip cache
RUN mkdir -p /workspaces && chgrp ${USER_GID} /workspaces \
    && mkdir -p ${HOME}/.vscode-server \
    && chown -R ${USERNAME}:${USERNAME} ${HOME}/.vscode-server \
    && mkdir -p ${HOME}/.cache/pip \
    && chown -R ${USERNAME}:${USERNAME} ${HOME}/.cache \
    && mkdir -p /root/.cache/pip

RUN touch /root/.z /home/vscode/.z \
    && mkdir -p /root/.oh-my-zsh/custom/plugins/git-flow-completion \
    && git clone https://github.com/petervanderdoes/git-flow-completion /root/.oh-my-zsh/custom/plugins/git-flow-completion \
    && git clone https://github.com/zsh-users/zsh-autosuggestions /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions \
    && git clone https://github.com/esc/conda-zsh-completion /root/.oh-my-zsh/custom/plugins/conda-zsh-completion \
    && cp -R /root/.oh-my-zsh/custom/plugins/* ${HOME}/.oh-my-zsh/custom/plugins/ \
    && chown -R ${USERNAME}:${USERNAME} ${HOME} \
    && sed -i -r 's/^(plugins=)\(([a-z \-]+)\)/\1\(\2 git-flow-completion conda-zsh-completion zsh-autosuggestions docker z\)/g' ${HOME}/.zshrc \
    && sed -i -r 's/^(plugins=)\(([a-z \-]+)\)/\1\(\2 git-flow-completion conda-zsh-completion zsh-autosuggestions docker z\)/g' /root/.zshrc

USER ${USERNAME}

VOLUME [ "/var/lib/docker" ]
# Setting the ENTRYPOINT to docker-init.sh will configure non-root access to
# the Docker socket if "overrideCommand": false is set in devcontainer.json.
# The script will also execute CMD if you need to alter startup behaviors.
ENTRYPOINT [ "/usr/bin/tini", "--", "/usr/local/share/docker-init.sh" ]
CMD [ "sleep", "infinity" ]
