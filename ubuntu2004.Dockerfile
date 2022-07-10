FROM ubuntu:20.04

# Set username, password, uid and guid
ARG USERNAME=vscode
ARG PASSWORD=vscode
ARG USER_UID=1001
ARG USER_GID=$USER_UID
ENV HOME=/home/${USERNAME}

ENV NVM_DIR="/usr/local/share/nvm"
ENV NVM_SYMLINK_CURRENT=true \
PATH=${NVM_DIR}/current/bin:${PATH}


ARG PYTHON_PATH=/usr/local/python
ENV PIPX_HOME=/usr/local/py-utils \
    PIPX_BIN_DIR=/usr/local/py-utils/bin
ENV PATH=${PYTHON_PATH}/bin:${PATH}:${PIPX_BIN_DIR}

# Config shell
ARG INSTALL_ZSH="true"

USER root

# Install needed packages and setup non-root user. Use a separate RUN statement to add your own dependencies.
# git-flow-debian.sh from https://github.com/petervanderdoes/gitflow-avh
COPY script-library/common-debian.sh \
    script-library/git-lfs-debian.sh \
    script-library/git-flow-debian.sh \
    script-library/node-debian.sh \
    script-library/python-debian.sh \
    /tmp/library-scripts/

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && bash /tmp/library-scripts/common-debian.sh "${INSTALL_ZSH}" "${USERNAME}" "${USER_UID}" "${USER_GID}" "${UPGRADE_PACKAGES}" \
    && if [ "$INSTALL_ZSH" = "true" ]; then usermod --shell /bin/zsh ${USERNAME}; fi \
    && bash /tmp/library-scripts/git-lfs-debian.sh \
    && bash /tmp/library-scripts/node-debian.sh "${NVM_DIR}" "16" \
    && bash /tmp/library-scripts/python-debian.sh "3.9.9" "${PYTHON_PATH}" "${PIPX_HOME}" \
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
    && sed -i -r 's/^(plugins=)\(([a-z \-]+)\)/\1\(\2 git-flow-completion conda-zsh-completion zsh-autosuggestions z\)/g' ${HOME}/.zshrc \
    && sed -i -r 's/^(plugins=)\(([a-z \-]+)\)/\1\(\2 git-flow-completion conda-zsh-completion zsh-autosuggestions z\)/g' /root/.zshrc

USER ${USERNAME}

CMD [ "sleep", "infinity" ]
