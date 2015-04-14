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
  SwitchIOS
} = React;

var Button = require('react-native-button');
var Camera = require('react-native-camera');
var VideoCameraExample = React.createClass({
  getInitialState() {
    return {
      frontCamera: true
    };
  },
  render() {
    return (
      <View>
        <View>
          <Camera
            ref="cam"
            aspect="Fit"
            type={this.state.frontCamera ? 'Front' : 'Back'}
            orientation="PortraitUpsideDown"
            style={{height: 300, width: 300, backgroundColor: 'blue'}}
          />
        </View>
        <SwitchIOS
          onValueChange={(value) => this.setCamera(value)}
          value={this.state.frontCamera}
          ref="switch" />
        <Button style={{color: 'green', padding: 20, margin: 10}} onPress={this.start}>
         Start
        </Button>
        <Button style={{color: 'red', padding: 20, margin: 10}} onPress={this.stop}>
         Stop
        </Button>
      </View>
    );
  },
  setCamera: function(val) {
    this.setState({frontCamera: val});
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
