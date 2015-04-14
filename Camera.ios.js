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

    aspect = NativeModules.CameraManager.aspects[this.props.aspect || 'Fill'];
    type = NativeModules.CameraManager.cameras[this.props.type ||'Back'];
    orientation = NativeModules.CameraManager.orientations[this.props.orientation || 'Portrait'];

    var nativeProps = merge(this.props, {
      style,
      aspect: aspect,
      type: type,
      orientation: orientation,
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
  }
});

var RCTCamera = createReactIOSNativeComponentClass({
  validAttributes: merge(ReactIOSViewAttributes.UIView, {
    aspect: true,
    type: true,
    orientation: true
  }),
  uiViewClassName: 'RCTCamera',
});

var styles = StyleSheet.create({
  base: { },
});

module.exports = Camera;
