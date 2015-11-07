SWIFT_FILE?=SimRecorder/main.swift
CARTAGE_PATH?=Carthage/Build/Mac
EXECUTABLE_PATH?=build/simrec
TARGET_SDK?=macosx
BUILD_TOOL?=xcrun
BUILD_OPTION?=-sdk $(TARGET_SDK) swiftc $(SWIFT_FILE) -F$(CARTAGE_PATH) -Xlinker -rpath -Xlinker $(CARTAGE_PATH) -o $(EXECUTABLE_PATH)

all:
	mkdir -p build
	$(BUILD_TOOL) $(BUILD_OPTION)

clean:
	rm $(EXECUTABLE_PATH)
