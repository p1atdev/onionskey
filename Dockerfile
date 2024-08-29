ARG BUN_VERSION=1.1.26
ARG NODE_VERSION=20.16.0

# build assets & compile TypeScript

FROM --platform=$BUILDPLATFORM oven/bun:${BUN_VERSION} AS installer

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked \
	rm -f /etc/apt/apt.conf.d/docker-clean \
	; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache \
	&& apt-get update \
	&& apt-get install -yqq --no-install-recommends \
	build-essential git

WORKDIR /misskey

COPY --link ["package.json", "./"]
COPY --link ["bun.lockb", "./"]
COPY --link ["scripts", "./scripts"]
COPY --link ["packages/backend/package.json", "./packages/backend/"]
COPY --link ["packages/frontend/package.json", "./packages/frontend/"]
COPY --link ["packages/sw/package.json", "./packages/sw/"]
COPY --link ["packages/misskey-js/package.json", "./packages/misskey-js/"]

ARG NODE_ENV=production

RUN --mount=type=cache,target=/root/.bun/install,sharing=locked \
	bun i --frozen-lockfile --aggregate-output --production

COPY --link . ./

RUN git submodule update --init
RUN rm -rf .git/

FROM --platform=$BUILDPLATFORM node:${NODE_VERSION}-bullseye AS native-builder

WORKDIR /misskey
ARG NODE_ENV=production

COPY --link ["package.json", "./"]
COPY --link ["packages/backend/package.json", "./packages/backend/"]
COPY --link ["packages/frontend/package.json", "./packages/frontend/"]
COPY --link ["packages/sw/package.json", "./packages/sw/"]
COPY --link ["packages/misskey-js/package.json", "./packages/misskey-js/"]
COPY --from=installer /misskey ./

RUN curl -fsSL https://bun.sh/install | bash -s bun-v1.1.26

RUN corepack enable

RUN PATH="$HOME/.bun/bin:$PATH" && bun run --production build

FROM --platform=$TARGETPLATFORM oven/bun:${BUN_VERSION}-slim AS runner

ARG UID="991"
ARG GID="991"

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
	ffmpeg tini curl libjemalloc-dev libjemalloc2 \
	&& ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so \
	&& groupadd -g "${GID}" misskey \
	&& useradd -l -u "${UID}" -g "${GID}" -m -d /misskey misskey \
	&& find / -type d -path /sys -prune -o -type d -path /proc -prune -o -type f -perm /u+s -ignore_readdir_race -exec chmod u-s {} \; \
	&& find / -type d -path /sys -prune -o -type d -path /proc -prune -o -type f -perm /g+s -ignore_readdir_race -exec chmod g-s {} \; \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists

USER misskey
WORKDIR /misskey

# add package.json to add pnpm
COPY --chown=misskey:misskey . ./

COPY --chown=misskey:misskey --from=native-builder /misskey/node_modules ./node_modules
COPY --chown=misskey:misskey --from=native-builder /misskey/built ./built
COPY --chown=misskey:misskey --from=native-builder /misskey/packages/misskey-js/built ./packages/misskey-js/built
COPY --chown=misskey:misskey --from=native-builder /misskey/packages/backend/built ./packages/backend/built
COPY --chown=misskey:misskey --from=native-builder /misskey/fluent-emojis /misskey/fluent-emojis

ENV LD_PRELOAD=/usr/local/lib/libjemalloc.so
ENV NODE_ENV=production
HEALTHCHECK --interval=5s --retries=20 CMD ["/bin/bash", "/misskey/healthcheck.sh"]
ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["bun", "run", "migrateandstart:docker"]
