# iOS Sim Recorder

## Install


```
$ brew install carthage
$ brew tap giginet/utils
$ brew install simrec
```

## Usage

1. Launch your iOS Simulator
2. Exec `simrec`
3. Stop recording with `Ctrl-C`

```
$ simrec
```

You'd like to stop recording, you send INTERRUPT signal(`Ctrl + C`), then an animation will be generated.

### Command Line Options

|Option|Description|Default|
|------|-----------|-------|
|-q    |Quality of animation(0...1.0) |1.0|
|-f    |Frame rate of animation |5|
|-o    |Output path|animation.gif|
|-l    |loop count of animation|0(Infinity)|
