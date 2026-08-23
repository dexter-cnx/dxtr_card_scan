/// User-visible strings for the package-owned Camera capture surface.
///
/// Applications can provide translated/localized strings without replacing
/// package behavior.
class CardCaptureLabels {
  const CardCaptureLabels({
    this.closeTooltip = 'Close',
    this.flashOff = 'Flash off',
    this.flashAuto = 'Flash auto',
    this.flashOn = 'Flash on',
    this.torchTooltip = 'Torch',
    this.processing = 'Processing image…',
    this.cameraUnavailable = 'Camera is unavailable.',
    this.captureFailed = 'Unable to capture image.',
    this.confirmTitle = 'Confirm scan',
    this.confirmAction = 'Use scan',
    this.retakeAction = 'Retake',
  });

  final String closeTooltip;
  final String flashOff;
  final String flashAuto;
  final String flashOn;
  final String torchTooltip;
  final String processing;
  final String cameraUnavailable;
  final String captureFailed;
  final String confirmTitle;
  final String confirmAction;
  final String retakeAction;
}

/// User-visible strings for the package-owned Gallery picker/crop surface.
class GalleryCropLabels {
  const GalleryCropLabels({
    this.title = 'Gallery crop',
    this.closeTooltip = 'Close',
    this.emptyMessage = 'Pick an image to begin.',
    this.pickAction = 'Pick image',
    this.pickAnotherAction = 'Pick another',
    this.instruction =
        'Keep the whole card inside the crop. The processor will detect the card edges and correct perspective inside this area.',
    this.preparing = 'Preparing image…',
    this.processing = 'Detecting and rectifying card…',
    this.scanAction = 'Scan selection',
    this.confirmTitle = 'Confirm scan',
    this.confirmAction = 'Use scan',
    this.retryAction = 'Adjust crop',
    this.errorPrefix = 'Processor error',
    this.dismissErrorTooltip = 'Dismiss error',
  });

  final String title;
  final String closeTooltip;
  final String emptyMessage;
  final String pickAction;
  final String pickAnotherAction;
  final String instruction;
  final String preparing;
  final String processing;
  final String scanAction;
  final String confirmTitle;
  final String confirmAction;
  final String retryAction;
  final String errorPrefix;
  final String dismissErrorTooltip;
}
