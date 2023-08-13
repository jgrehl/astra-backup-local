group "default" {
	targets = ["debian-latest", "alpine-latest", "debian-19", "debian-18", "debian-17", "debian-16", "debian-11", "alpine-19", "alpine-18", "alpine-17", "alpine-16", "alpine-11"]
}

variable "REGISTRY_PREFIX" {
	default = ""
}

variable "IMAGE_NAME" {
	default = "astradb-backup-local"
}

variable "BUILD_REVISION" {
	default = ""
}

target "debian" {
	args = {"GOCRONVER" = "v0.0.10"}
	dockerfile = "debian.Dockerfile"
}

target "alpine" {
	args = {"GOCRONVER" = "v0.0.10"}
	dockerfile = "alpine.Dockerfile"
}


target "debian-latest" {
	inherits = ["debian"]
	platforms = ["linux/amd64", "linux/arm64"]
	args = {"BASETAG" = "20"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:latest",
		"${REGISTRY_PREFIX}${IMAGE_NAME}:20",
		notequal("", BUILD_REVISION) ? "${REGISTRY_PREFIX}${IMAGE_NAME}:20-debian-${BUILD_REVISION}" : ""
	]
}

target "alpine-latest" {
	inherits = ["alpine"]
	platforms = ["linux/amd64"]
	args = {"BASETAG" = "20-alpine"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:alpine",
		"${REGISTRY_PREFIX}${IMAGE_NAME}:20-alpine",
		notequal("", BUILD_REVISION) ? "${REGISTRY_PREFIX}${IMAGE_NAME}:20-alpine-${BUILD_REVISION}" : ""
	]
}

target "debian-19" {
	inherits = ["debian"]
	platforms = ["linux/amd64", "linux/arm64"]
	args = {"BASETAG" = "19"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:19",
		notequal("", BUILD_REVISION) ? "${REGISTRY_PREFIX}${IMAGE_NAME}:19-debian-${BUILD_REVISION}" : ""
	]
}

target "alpine-19" {
	inherits = ["alpine"]
	platforms = ["linux/amd64"]
	args = {"BASETAG" = "19-alpine"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:19-alpine",
		notequal("", BUILD_REVISION) ? "${REGISTRY_PREFIX}${IMAGE_NAME}:19-alpine-${BUILD_REVISION}" : ""
	]
}

target "debian-18" {
	inherits = ["debian"]
	platforms = ["linux/amd64", "linux/arm64"]
	args = {"BASETAG" = "18"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:18",
		notequal("", BUILD_REVISION) ? "${REGISTRY_PREFIX}${IMAGE_NAME}:18-debian-${BUILD_REVISION}" : ""
	]
}

target "alpine-18" {
	inherits = ["alpine"]
	platforms = ["linux/amd64"]
	args = {"BASETAG" = "18-alpine"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:18-alpine",
		notequal("", BUILD_REVISION) ? "${REGISTRY_PREFIX}${IMAGE_NAME}:18-alpine-${BUILD_REVISION}" : ""
	]
}

target "debian-17" {
	inherits = ["debian"]
	platforms = ["linux/amd64", "linux/arm64"]
	args = {"BASETAG" = "17"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:17",
		notequal("", BUILD_REVISION) ? "${REGISTRY_PREFIX}${IMAGE_NAME}:17-debian-${BUILD_REVISION}" : ""
	]
}

target "alpine-17" {
	inherits = ["alpine"]
	platforms = ["linux/amd64"]
	args = {"BASETAG" = "17-alpine"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:17-alpine",
		notequal("", BUILD_REVISION) ? "${REGISTRY_PREFIX}${IMAGE_NAME}:17-alpine-${BUILD_REVISION}" : ""
	]
}

target "debian-16" {
	inherits = ["debian"]
	platforms = ["linux/amd64", "linux/arm64"]
	args = {"BASETAG" = "16"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:16",
		notequal("", BUILD_REVISION) ? "${REGISTRY_PREFIX}${IMAGE_NAME}:16-debian-${BUILD_REVISION}" : ""
	]
}

target "alpine-16" {
	inherits = ["alpine"]
	platforms = ["linux/amd64"]
	args = {"BASETAG" = "16-alpine"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:16-alpine",
		notequal("", BUILD_REVISION) ? "${REGISTRY_PREFIX}${IMAGE_NAME}:16-alpine-${BUILD_REVISION}" : ""
	]
}

target "debian-11" {
	inherits = ["debian"]
	platforms = ["linux/amd64", "linux/arm64"]
	args = {"BASETAG" = "11"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:11",
		notequal("", BUILD_REVISION) ? "${REGISTRY_PREFIX}${IMAGE_NAME}:11-debian-${BUILD_REVISION}" : ""
	]
}

target "alpine-11" {
	inherits = ["alpine"]
	platforms = ["linux/amd64"]
	args = {"BASETAG" = "11-alpine"}
	tags = [
		"${REGISTRY_PREFIX}${IMAGE_NAME}:11-alpine",
		notequal("", BUILD_REVISION) ? "${REGISTRY_PREFIX}${IMAGE_NAME}:11-alpine-${BUILD_REVISION}" : ""
	]
}
