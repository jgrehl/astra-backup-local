#!/bin/sh

set -e

GOCRONVER="v0.0.10"
MAIN_TAG="20"
TAGS_EXTRA="19 18 17 16 15 14 13 12 11"
PLATFORMS_DEBIAN="linux/amd64 linux/arm64"
PLATFORMS_APLINE="linux/amd64"
DOCKER_BAKE_FILE="${1:-docker-bake.hcl}"

cd "$(dirname "$0")"

P_A="\"$(echo $PLATFORMS_APLINE | sed 's/ /", "/g')\""
P_D="\"$(echo $PLATFORMS_DEBIAN | sed 's/ /", "/g')\""

T="\"debian-latest\", \"alpine-latest\", \"$(echo debian-$TAGS_EXTRA | sed 's/ /", "debian-/g')\", \"$(echo alpine-$TAGS_EXTRA | sed 's/ /", "alpine-/g')\""

cat > "$DOCKER_BAKE_FILE" << EOF
group "default" {
	targets = [$T]
}

variable "REGISTRY_PREFIX" {
	default = ""
}

variable "IMAGE_NAME" {
	default = "astra-backup-local"
}

variable "BUILD_REVISION" {
	default = ""
}

target "debian" {
	args = {"GOCRONVER" = "$GOCRONVER"}
	dockerfile = "debian.Dockerfile"
}

target "alpine" {
	args = {"GOCRONVER" = "$GOCRONVER"}
	dockerfile = "alpine.Dockerfile"
}


target "debian-latest" {
	inherits = ["debian"]
	platforms = [$P_D]
	args = {"BASETAG" = "$MAIN_TAG"}
	tags = [
		"\${REGISTRY_PREFIX}\${IMAGE_NAME}:latest",
		"\${REGISTRY_PREFIX}\${IMAGE_NAME}:$MAIN_TAG",
		notequal("", BUILD_REVISION) ? "\${REGISTRY_PREFIX}\${IMAGE_NAME}:$MAIN_TAG-debian-\${BUILD_REVISION}" : ""
	]
}

target "alpine-latest" {
	inherits = ["alpine"]
	platforms = [$P_A]
	args = {"BASETAG" = "$MAIN_TAG-alpine"}
	tags = [
		"\${REGISTRY_PREFIX}\${IMAGE_NAME}:alpine",
		"\${REGISTRY_PREFIX}\${IMAGE_NAME}:$MAIN_TAG-alpine",
		notequal("", BUILD_REVISION) ? "\${REGISTRY_PREFIX}\${IMAGE_NAME}:$MAIN_TAG-alpine-\${BUILD_REVISION}" : ""
	]
}
EOF

for TAG in $TAGS_EXTRA; do cat >> "$DOCKER_BAKE_FILE" << EOF

target "debian-$TAG" {
	inherits = ["debian"]
	platforms = [$P_D]
	args = {"BASETAG" = "$TAG"}
	tags = [
		"\${REGISTRY_PREFIX}\${IMAGE_NAME}:$TAG",
		notequal("", BUILD_REVISION) ? "\${REGISTRY_PREFIX}\${IMAGE_NAME}:$TAG-debian-\${BUILD_REVISION}" : ""
	]
}

target "alpine-$TAG" {
	inherits = ["alpine"]
	platforms = [$P_A]
	args = {"BASETAG" = "$TAG-alpine"}
	tags = [
		"\${REGISTRY_PREFIX}\${IMAGE_NAME}:$TAG-alpine",
		notequal("", BUILD_REVISION) ? "\${REGISTRY_PREFIX}\${IMAGE_NAME}:$TAG-alpine-\${BUILD_REVISION}" : ""
	]
}
EOF
done
