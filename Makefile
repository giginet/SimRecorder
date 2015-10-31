BUILD_TOOL?=xcodebuild
XCODEFLAGS=-project 'SimRecorder.xcodeproj'

all:
	$(BUILD_TOOL) $(XCODEFLAGS) build
