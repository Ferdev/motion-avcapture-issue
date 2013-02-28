class CapturerController < UIViewController

  def viewDidAppear(animated)
    setup_capture_session
  end

  def realtime
    @realtime ||= UIView.alloc.initWithFrame(UIScreen.mainScreen.bounds).tap do |realtime|
      view.addSubview(realtime)
    end
  end

  def setup_capture_session
    capture_session = AVCaptureSession.new
    capture_session.setSessionPreset(AVCaptureSessionPresetHigh)

    device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)

    device.lockForConfiguration(nil)
    device.focusMode = AVCaptureFocusModeContinuousAutoFocus
    device.unlockForConfiguration

    device_input = AVCaptureDeviceInput.deviceInputWithDevice(device, error: nil)

    capture_session.addInput(device_input) if capture_session.canAddInput(device_input)

    AVCaptureVideoPreviewLayer.layerWithSession(capture_session).tap do |o|
      o.setVideoGravity(AVLayerVideoGravityResizeAspectFill)
      o.frame = realtime.bounds
      realtime.layer.addSublayer(o)
    end

    data_output               = AVCaptureVideoDataOutput.new

    queue = Dispatch::Queue.new('wadus')
    data_output.setSampleBufferDelegate(self, queue: queue.dispatch_object)

    data_output.videoSettings = {KCVPixelBufferPixelFormatTypeKey => KCVPixelFormatType_420YpCbCr8BiPlanarFullRange}

    data_output.setAlwaysDiscardsLateVideoFrames(true)

    capture_session.addOutput(data_output) if capture_session.canAddOutput(data_output)

    data_output.connections.each do |connection|
      if connection.isVideoOrientationSupported
        connection.videoMinFrameDuration = CMTimeMake(1,24)
        connection.videoMaxFrameDuration = CMTimeMake(1,24)
        connection.setVideoOrientation(AVCaptureVideoOrientationPortrait)
      end
    end

    capture_session.commitConfiguration

    capture_session.startRunning
  end

  def captureOutput(captureOutput, didOutputSampleBuffer: sampleBuffer, fromConnection: connection)
    image_buffer =  CMSampleBufferGetImageBuffer(sampleBuffer)
    CVPixelBufferLockBaseAddress(image_buffer, 0)

    bytes_per_row = CVPixelBufferGetBytesPerRowOfPlane(image_buffer, 0)
    luma_buffer = CVPixelBufferGetBaseAddress(image_buffer)

    CVPixelBufferRelease(luma_buffer)
    CVPixelBufferUnlockBaseAddress(image_buffer, 0)
  end
end

