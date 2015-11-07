SWIFT_FILE?=SimRecorder/main.swift
CARTAGE_PATH?=Carthage/Build/Mac
FRAMEWORK_PATH?=@executable_path/../Frameworks/
EXECUTABLE_PATH?=build/simrec
TARGET_SDK?=macosx
BUILD_TOOL?=xcrun
BUILD_OPTION?=-sdk $(TARGET_SDK) swiftc $(SWIFT_FILE) -F$(CARTAGE_PATH) -Xlinker -rpath -Xlinker "$(FRAMEWORK_PATH)" -o $(EXECUTABLE_PATH)

bootstrap:
	carthage update

build: bootstrap
	mkdir -p build
	$(BUILD_TOOL) $(BUILD_OPTION)

clean:
	rm $(EXECUTABLE_PATH)

prefix_install: build
	mkdir -p "$(PREFIX)/Frameworks" "$(PREFIX)/bin"
	cp -rf $(CARTAGE_PATH)/OptionKit.framework "$(PREFIX)/Frameworks/"
	cp build/simrec "$(PREFIX)/bin/"
