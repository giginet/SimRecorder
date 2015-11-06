BUILD_TOOL?=xcodebuild
XCODEFLAGS=-workspace 'SimRecorder.xcworkspace' -scheme 'SimRecorder-Release'

all:
	$(BUILD_TOOL) $(XCODEFLAGS) build
