var React = require('React');
var NativeModules = require('NativeModules');
var ReactIOSViewAttributes = require('ReactIOSViewAttributes');
var StyleSheet = require('StyleSheet');
var createReactIOSNativeComponentClass = require('createReactIOSNativeComponentClass');
var PropTypes = require('ReactPropTypes');
var StyleSheetPropType = require('StyleSheetPropType');
var NativeMethodsMixin = require('NativeMethodsMixin');
var flattenStyle = require('flattenStyle');
var merge = require('merge');

var Camera = React.createClass({
  propTypes: {
    aspect: PropTypes.string,
    type: PropTypes.string,
    orientation: PropTypes.string,
    frameRate: PropTypes.number,
    maxDuration: React.PropTypes.number,
    maxFileSize: React.PropTypes.number,

    onRecordStart: PropTypes.func,
    onRecordEnd: PropTypes.func,
    onFrameRateChange: PropTypes.func,
    onRecordSaved: PropTypes.func
  },

  mixins: [NativeMethodsMixin],

  viewConfig: {
    uiViewClassName: 'UIView',
    validAttributes: ReactIOSViewAttributes.UIView
  },

  getInitialState: function() {
    return {
      isAuthorized: false
    };
  },

  componentWillMount: function() {
    NativeModules.CameraManager.checkDeviceAuthorizationStatus((function(err, isAuthorized) {
      this.state.isAuthorized = isAuthorized;
      this.setState(this.state);
    }).bind(this));
  },

  render: function() {
    var style = flattenStyle([styles.base, this.props.style]);

    var aspect = NativeModules.CameraManager.aspects[this.props.aspect || 'Fill'];
    var type = NativeModules.CameraManager.cameras[this.props.type ||'Back'];
    var orientation = NativeModules.CameraManager.orientations[this.props.orientation || 'Portrait'];
    var frameRate = this.props.frameRate > 0 ? this.props.frameRate : 25;
    var maxFileSize = this.props.maxFileSize || 0;
    var maxDuration = this.props.maxDuration || 0;

    if (maxDuration === Infinity) {
      maxDuration = 0;
    }

    var nativeProps = merge(this.props, {
      style,
      aspect,
      type,
      orientation,
      frameRate,
      maxFileSize,
      maxDuration,

      onRecordStart: this.onRecordStart,
      onRecordEnd: this.onRecordEnd,
      onFrameRateChange: this.onFrameRateChange,
      onRecordSaved: this.onRecordSaved
    });

    return <RCTCamera {... nativeProps} />
  },

  takePicture: function(cb) {
    NativeModules.CameraManager.takePicture(cb);
  },

  startRecording: function(cb) {
    NativeModules.CameraManager.startRecording();
  },

  stopRecording: function(cb) {
    NativeModules.CameraManager.stopRecording();
  },

  // Events

  onRecordStart(event) {
    if (this.props.onRecordStart) {
      this.props.onRecordStart(event.nativeEvent);
    }
  },

  onRecordEnd(event) {
    if (this.props.onRecordEnd) {
      this.props.onRecordEnd(event.nativeEvent);
    }
  },

  onFrameRateChange(event) {
    if (this.props.onFrameRateChange) {
      this.props.onFrameRateChange(event.nativeEvent);
    }
  },

  onRecordSaved(event) {
    if (this.props.onRecordSaved) {
      this.props.onRecordSaved(event.nativeEvent);
    }
  }
});

var RCTCamera = createReactIOSNativeComponentClass({
  validAttributes: merge(ReactIOSViewAttributes.UIView, {
    aspect: true,
    type: true,
    orientation: true,
    frameRate: true,
    maxDuration: true,
    maxFileSize: true
  }),
  uiViewClassName: 'RCTCamera',
});

var styles = StyleSheet.create({
  base: { },
});

module.exports = Camera;
