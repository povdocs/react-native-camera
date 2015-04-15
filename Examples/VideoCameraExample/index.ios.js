/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 */
'use strict';

var React = require('react-native');
var {
  AppRegistry,
  StyleSheet,
  Text,
  View,
  SwitchIOS,
  SliderIOS
} = React;

var Button = require('react-native-button');
var Camera = require('react-native-camera');
var VideoCameraExample = React.createClass({
  getInitialState() {
    return {
      frontCamera: true,
      frameRate: 24
    };
  },
  render() {
    /*
    todo: set SliderIOS range to 0-60, once min/max value are supported
    https://github.com/facebook/react-native/pull/583/
    */
    return (
      <View>
        <View>
          <Camera
            ref="cam"
            aspect="Fit"
            type={this.state.frontCamera ? 'Front' : 'Back'}
            orientation="PortraitUpsideDown"
            frameRate={this.state.frameRate}
            style={{height: 200, width: 300, backgroundColor: 'blue'}}
            onRecordStart={this.recordStart}
            onRecordEnd={this.recordEnd}
            onRecordSaved={this.recordSaved}
            onFrameRateChange={(evt) => console.log('onFrameRateChange', evt)}
            maxFileSize={20 * 1000 * 1000}
          />
        </View>
        <SwitchIOS
          onValueChange={(value) => this.updateState({frontCamera: value})}
          value={this.state.frontCamera}
          ref="switch" />
        <SliderIOS
          value={this.state.frameRate / 60}
          onSlidingComplete={(value) => this.updateState({frameRate: value * 60})} />
        <Button style={{color: 'green', padding: 20, margin: 10}} onPress={this.start}>
         Start
        </Button>
        <Button style={{color: 'red', padding: 20, margin: 10}} onPress={this.stop}>
         Stop
        </Button>
      </View>
    );
  },
  updateState: function(newState) {
    this.setState(newState);
  },
  _takePicture() {
    this.refs.cam.takePicture(function (err, base64EncodedJpeg) {
      // body...
    });
  },
  start() {
    this.refs.cam.startRecording();
  },
  stop() {
    this.refs.cam.stopRecording();
  },
  recordStart(event) {
    console.log('started recording', event);
  },
  recordEnd(event) {
    console.log('stopped recording', event);
  },
  recordSaved(event) {
    console.log('recording saved', event);
  }
});

var styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5FCFF',
  },
  welcome: {
    fontSize: 20,
    textAlign: 'center',
    margin: 10,
  },
  instructions: {
    textAlign: 'center',
    color: '#333333',
    marginBottom: 5,
  },
});

AppRegistry.registerComponent('VideoCameraExample', () => VideoCameraExample);
