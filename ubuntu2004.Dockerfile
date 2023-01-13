FROM ubuntu:20.04

# Set username, password, uid and guid
ARG USERNAME=vscode
ARG PASSWORD=vscode
ARG USER_UID=1001
ARG USER_GID=$USER_UID
ENV HOME=/home/${USERNAME}

ARG UPGRADE_PACKAGES="true"
ARG ADDITIONAL_PACKAGES="tini tmux tree nmon inetutils-ping make"

ENV DOCKER_BUILDKIT=1

ENV NVM_DIR="/usr/local/share/nvm"
ENV NVM_SYMLINK_CURRENT=true \
PATH=${NVM_DIR}/current/bin:${PATH}

ARG PYTHON_PATH=/usr/local/python
ENV PIPX_HOME=/usr/local/py-utils \
    PIPX_BIN_DIR=/usr/local/py-utils/bin
ENV PATH=${PYTHON_PATH}/bin:${PATH}:${PIPX_BIN_DIR}
ENV GOROOT=/usr/local/go \
    GOPATH=/go
ENV PATH=${GOPATH}/bin:${GOROOT}/bin:${PATH}


# Config shell
ARG INSTALL_ZSH="true"

USER root

# Install needed packages and setup non-root user. Use a separate RUN statement to add your own dependencies.
# git-flow-debian.sh from https://github.com/petervanderdoes/gitflow-avh
COPY script-library/common-debian.sh \
    script-library/git-lfs-debian.sh \
    script-library/git-flow-debian.sh \
    script-library/docker-in-docker-debian.sh \
    script-library/node-debian.sh \
    script-library/python-debian.sh \
    script-library/go-debian.sh \
    script-library/install-debian.sh \
    /tmp/library-scripts/

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && bash /tmp/library-scripts/common-debian.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" \
    && if [ "$INSTALL_ZSH" = "true" ]; then usermod --shell /bin/zsh ${USERNAME}; fi \
    && bash /tmp/library-scripts/install-debian.sh "${ADDITIONAL_PACKAGES}" \
    && bash /tmp/library-scripts/node-debian.sh "${NVM_DIR}" "18" \
    && bash /tmp/library-scripts/go-debian.sh "latest" "${GOROOT}" "${GOPATH}" \
    && bash /tmp/library-scripts/python-debian.sh "3.11.1" "${PYTHON_PATH}" "${PIPX_HOME}" \
    && /bin/bash /tmp/library-scripts/docker-in-docker-debian.sh \
    && bash /tmp/library-scripts/git-lfs-debian.sh \
    && bash /tmp/library-scripts/git-flow-debian.sh "/usr/local" "gitflow" "https://github.com/petervanderdoes/gitflow-avh.git" "install" "stable" \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/library-scripts 

# Set up folders for vscode workspaces, extensions/pip cache
RUN mkdir -p /workspaces && chgrp ${USER_GID} /workspaces \
    && mkdir -p ${HOME}/.vscode-server/data/Machine \
    && chown -R ${USERNAME}:${USERNAME} ${HOME}/.vscode-server \
    && mkdir -p ${HOME}/.cache/pip \
    && chown -R ${USERNAME}:${USERNAME} ${HOME}/.cache \
    && mkdir -p ${HOME}/.config \
    && chown -R ${USERNAME}:${USERNAME} ${HOME}/.config \
    && mkdir -p ${HOME}/.docker \
    && chown -R ${USERNAME}:${USERNAME} ${HOME}/.docker \    
    && mkdir -p /root/.cache/pip

RUN pip3 install ansible jmespath docker --no-cache-dir  \
    && TEMP_DEB="$(mktemp)" \
    && wget -O "$TEMP_DEB" 'https://github.com/go-task/task/releases/download/v3.19.1/task_linux_amd64.deb' \
    && dpkg -i "$TEMP_DEB" \
    && rm -f "$TEMP_DEB" \
    && TEMP_DEB="$(mktemp)" \
    && wget -O "$TEMP_DEB" 'https://github.com/goreleaser/goreleaser/releases/download/v1.14.1/goreleaser_1.14.1_amd64.deb' \
    && dpkg -i "$TEMP_DEB" \
    && rm -f "$TEMP_DEB"

RUN touch /root/.z /home/vscode/.z \
    && mkdir -p /root/.oh-my-zsh/custom/plugins/git-flow-completion \
    && git clone https://github.com/petervanderdoes/git-flow-completion /root/.oh-my-zsh/custom/plugins/git-flow-completion \
    && git clone https://github.com/zsh-users/zsh-autosuggestions /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions \
    && git clone https://github.com/esc/conda-zsh-completion /root/.oh-my-zsh/custom/plugins/conda-zsh-completion \
    && git clone https://github.com/sawadashota/go-task-completions.git /root/.oh-my-zsh/custom/plugins/task \
    && cp -R /root/.oh-my-zsh/custom/plugins/* ${HOME}/.oh-my-zsh/custom/plugins/ \
    && chown -R ${USERNAME}:${USERNAME} ${HOME} \
    && sed -i -r 's/^(plugins=)\(([a-z \-]+)\)/\1\(\2 git-flow-completion conda-zsh-completion zsh-autosuggestions docker ansible z\)/g' ${HOME}/.zshrc \
    && sed -i -r 's/^(plugins=)\(([a-z \-]+)\)/\1\(\2 git-flow-completion conda-zsh-completion zsh-autosuggestions docker ansible z\)/g' /root/.zshrc

WORKDIR ${HOME}
USER ${USERNAME}

VOLUME [ "/var/lib/docker" ]
# Setting the ENTRYPOINT to docker-init.sh will configure non-root access to
# the Docker socket if "overrideCommand": false is set in devcontainer.json.
# The script will also execute CMD if you need to alter startup behaviors.
ENTRYPOINT [ "/usr/bin/tini", "--", "/usr/local/share/docker-init.sh" ]
CMD [ "sleep", "infinity" ]
