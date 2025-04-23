// ignore_for_file: must_be_immutable

library chat_input;

import 'dart:async';
import 'dart:io';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:chat_input/blinking_widget.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';

///Chat input widget for chat screens
///supports audio,image and texts
///returns corresponding files or text based on user inputs
enum RecordingState {
  ready,
  recording,
}

/// Color options for customizing the InputWidget appearance
class ColorOptions {
  /// Background color of the input field
  final Color? fieldColor;

  /// Color of the microphone icon
  final Color? micColor;

  /// Color of the attachment icon
  final Color? attachmentIconColor;

  /// Color of hint text
  final Color? hintTextColor;

  /// Color of the recording timer text
  final Color? timerTextColor;

  /// Color of the send button
  final Color? sendButtonColor;

  /// Color of icons on primary colored backgrounds
  final Color? onPrimaryColor;

  /// Color for error states (like recording deletion)
  final Color? errorColor;

  /// Color for shadows
  final Color? shadowColor;

  const ColorOptions({
    this.fieldColor,
    this.micColor,
    this.attachmentIconColor,
    this.hintTextColor,
    this.timerTextColor,
    this.sendButtonColor,
    this.onPrimaryColor,
    this.errorColor,
    this.shadowColor,
  });

  /// Creates a ColorOptions instance from the current theme
  factory ColorOptions.fromTheme(ThemeData theme) {
    return ColorOptions(
      fieldColor: theme.cardColor,
      micColor: theme.colorScheme.primary,
      attachmentIconColor: theme.hintColor,
      hintTextColor: theme.hintColor,
      timerTextColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
      sendButtonColor: theme.colorScheme.primary,
      onPrimaryColor: theme.colorScheme.onPrimary,
      errorColor: theme.colorScheme.error,
      shadowColor: theme.shadowColor,
    );
  }
}

class InputWidget extends StatefulWidget {
  final void Function(File audioFile, Duration duration) onSendAudio;
  final Function(String text) onSendText;

  // final Function(File selectedFile) onSendImage;
  final Function? onAttachmentClick;
  final Function? onError;
  final EdgeInsetsGeometry? containerMargin;
  EdgeInsetsGeometry? attachmentDialogMargin;
  final EdgeInsetsGeometry? containerPadding;

  /// Color options for customizing the widget appearance
  final ColorOptions? colorOptions;
  final Widget? micIcon;
  final String? hintText;

  /// Override the default microphone visibility behavior
  final bool? showMicOverride;

  InputWidget({
    Key? key,
    required this.onSendAudio,
    required this.onSendText,
    this.onAttachmentClick,
    // required this.onSendImage,
    this.onError,
    this.containerPadding,
    this.containerMargin,
    this.micIcon,
    this.colorOptions,
    this.hintText,
    this.showMicOverride,
  }) : super(key: key);

  @override
  _InputWidgetState createState() => _InputWidgetState();
}

class _InputWidgetState extends State<InputWidget> {
  final TextEditingController _textEditingController = TextEditingController();
  final _audioRecorder = AudioRecorder();

  bool _showMike = true;
  RecordingState _recordingState = RecordingState.ready;
  int _secondsElapsed = 0;
  double _xTranslation = 0;
  bool _voiceCanceled = false;
  late Uuid _uuid;
  late File _recordedFile;

  ColorOptions get _colors =>
      widget.colorOptions ?? ColorOptions.fromTheme(Theme.of(context));

  @override
  void initState() {
    super.initState();
    _uuid = const Uuid();
    _initAudioRecorder();
    _showMike = widget.showMicOverride ?? true;
  }

  @override
  void didUpdateWidget(InputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showMicOverride != widget.showMicOverride) {
      setState(() {
        _showMike =
            widget.showMicOverride ?? _textEditingController.text.isEmpty;
      });
    }
  }

  // Initialize the audio recorder
  void _initAudioRecorder() async {
    try {
      // Initialization code for audio recorder (if any)
    } catch (e) {
      print("Error initializing audio recorder: $e");
    }
  }

  // Handle text input change
  void _onChangeText(String value) {
    setState(() {
      _showMike = widget.showMicOverride ?? value.isEmpty;
    });
  }

  // Show attachment options sheet
  void _showHideAttachmentSheet() {
    widget.onAttachmentClick?.call();
    // showModalBottomSheet<void>(
    //   context: context,
    //   isDismissible: true,
    //   barrierColor: Colors.black45.withOpacity(.1),
    //   builder: (BuildContext context) {
    //     return Container(
    //       // Attachment options sheet contents
    //     );
    //   },
    // );
  }

  // Start recording audio
  Future<void> _startRecording() async {
    _voiceCanceled = false;
    _recordedFile = File('');

    if (_recordingState == RecordingState.ready) {
      try {
        final String path =
            await getApplicationCacheDirectory().then((result) => result.path) +
                "${_uuid.v4()}.m4a";
        if (await _audioRecorder.hasPermission()) {
          await _audioRecorder.start(
            RecordConfig(),
            path: path,
          );
        }
        _recordingState = RecordingState.recording;
        _secondsElapsed = 0;
        _updateTimer();
        setState(() {});
      } catch (e) {
        print("Error starting recording: $e");
      }
    }
  }

  // Stop recording audio
  void _stopRecording({bool canceled = false}) async {
    if (_recordingState == RecordingState.recording) {
      try {
        var path = await _audioRecorder.stop();
        if (!canceled && path != null) {
          _recordedFile = File(path);
          widget.onSendAudio(_recordedFile, Duration(seconds: _secondsElapsed));
        } else {
          if (_recordedFile.existsSync()) {
            _recordedFile.delete();
          }
        }
        _recordingState = RecordingState.ready;
        _secondsElapsed = 0;
        setState(() {});
      } catch (e) {
        print("Error stopping recording: $e");
      }
    }
  }

  // Update recording timer
  void _updateTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_recordingState == RecordingState.recording) {
        setState(() {
          _secondsElapsed++;
          _updateTimer();
        });
      }
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Container(
            margin: const EdgeInsets.only(left: 5, right: 5 + 30),
            padding: widget.containerPadding ??
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _colors.fieldColor ?? Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.all(Radius.circular(50)),
                    boxShadow: [
                      BoxShadow(
                        spreadRadius: 5,
                        blurRadius: 5,
                        color: (_colors.shadowColor ??
                                Theme.of(context).shadowColor)
                            .withOpacity(.1),
                      )
                    ],
                  ),
                  child: _recordingState == RecordingState.recording
                      ? _buildRecordingWidget()
                      : _buildChatWidget(),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _showMike
                ? Transform.translate(
                    offset: Offset(_xTranslation, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_recordingState == RecordingState.recording &&
                            !_voiceCanceled)
                          Shimmer.fromColors(
                            baseColor: (_colors.timerTextColor ??
                                    Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color ??
                                    Colors.grey)
                                .withOpacity(.8),
                            highlightColor: _colors.sendButtonColor ??
                                Theme.of(context).colorScheme.primary,
                            period: const Duration(milliseconds: 1000),
                            direction: ShimmerDirection.rtl,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.keyboard_double_arrow_left,
                                  color: _colors.timerTextColor ??
                                      Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.6),
                                ),
                                Text(
                                  "Slide to cancel".toUpperCase(),
                                  style: TextStyle(
                                    color: _colors.timerTextColor ??
                                        Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                            ?.withOpacity(0.6),
                                    overflow: TextOverflow.clip,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 30),
                        MikeWidget(
                          onSlide: (double value) {
                            setState(() {
                              _xTranslation = value;
                            });
                          },
                          onStopRecording: (canceled) {
                            if (canceled) {
                              setState(() {
                                _voiceCanceled = true;
                                _xTranslation = 0;
                              });
                            } else {
                              _stopRecording(canceled: canceled);
                            }
                          },
                          startRecording: _startRecording,
                          micColor: _colors.micColor,
                          recording:
                              _recordingState == RecordingState.recording,
                        ),
                      ],
                    ),
                  )
                : _sendWidget(),
          ),
        ],
      ),
    );
  }

  // Build chat input widget
  Row _buildChatWidget() {
    return Row(
      children: [
        IconButton(
          onPressed: _showHideAttachmentSheet,
          icon: Icon(
            Icons.attach_file,
            size: 25,
            color: _colors.attachmentIconColor,
          ),
        ),
        Flexible(
          flex: 4,
          child: TextFormField(
            onChanged: _onChangeText,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: widget.hintText ?? "Type a message",
              hintStyle: TextStyle(
                color: _colors.hintTextColor,
                fontSize: 15,
              ),
            ),
            controller: _textEditingController,
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  // Build recording widget
  Row _buildRecordingWidget() {
    String formattedTime = _formatTime(_secondsElapsed);
    return Row(
      children: [
        !_voiceCanceled
            ? BlinkingWidget(
                child: widget.micIcon ??
                    IconButton(
                      onPressed: () {},
                      icon: Icon(
                        Icons.mic,
                        size: 30,
                        color: _colors.errorColor,
                      ),
                    ),
                duration: const Duration(milliseconds: 500),
              )
            : AnimatedMic(
                onAnimationCompleted: () {
                  setState(() {
                    _voiceCanceled = false;
                    _stopRecording(canceled: true);
                  });
                },
                colorOptions: _colors,
              ),
        const SizedBox(width: 10),
        Text(
          formattedTime,
          style: TextStyle(
            color: _colors.timerTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(width: 10),
        const Spacer(),
        const SizedBox(width: 10),
      ],
    );
  }

  // Format elapsed time as "00:00"
  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;

    String formattedMinutes = minutes.toString().padLeft(2, '0');
    String formattedSeconds = remainingSeconds.toString().padLeft(2, '0');

    return '$formattedMinutes:$formattedSeconds';
  }

  // Build send button widget
  Widget _sendWidget() {
    return InkWell(
      onTap: () {
        widget.onSendText(_textEditingController.text);
        _textEditingController.clear();
        setState(() {
          _showMike = true;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: (_colors.shadowColor ?? Theme.of(context).shadowColor)
                  .withOpacity(.2),
              blurRadius: 3,
              spreadRadius: 3,
            ),
          ],
          borderRadius: const BorderRadius.all(Radius.circular(50)),
          color: _colors.sendButtonColor,
        ),
        padding: const EdgeInsets.all(5),
        child: Icon(Icons.send, size: 25, color: _colors.onPrimaryColor),
      ),
    );
  }
}

class AnimatedMic extends StatefulWidget {
  const AnimatedMic({
    super.key,
    required this.onAnimationCompleted,
    this.colorOptions,
  });

  final Function onAnimationCompleted;
  final ColorOptions? colorOptions;

  @override
  State<AnimatedMic> createState() => _AnimatedMicState();
}

class _AnimatedMicState extends State<AnimatedMic>
    with TickerProviderStateMixin {
  bool showBin = false;
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        widget.colorOptions ?? ColorOptions.fromTheme(Theme.of(context));
    return SizedBox(
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.mic,
              size: 30,
              color: colors.errorColor,
            ),
          )
              .animate()
              .rotate(alignment: Alignment.center)
              .moveY(
                  curve: Curves.decelerate,
                  begin: 0,
                  end: -200,
                  duration: const Duration(milliseconds: 500))
              .callback(callback: (v) {
                showBin = true;
                setState(() {});
                print("up animation completed");
              })
              .then()
              .moveY(
                  begin: 0,
                  end: 200,
                  duration: const Duration(milliseconds: 500))
              .fadeOut(duration: const Duration(milliseconds: 500))
              .callback(callback: (v) {
                print("down animation completed");
                _controller?.forward();
              }),
          if (showBin)
            Icon(
              Icons.delete,
              color: colors.errorColor,
              size: 30,
            )
                .animate()
                .moveY(
                    begin: 100, end: 0, duration: Duration(milliseconds: 300))
                .animate(controller: _controller, autoPlay: false)
                .shake()
                .callback(callback: (v) {
              widget.onAnimationCompleted();
              print("shake animation completed");
            })
        ],
      ),
    );
  }
}

class MikeWidget extends StatefulWidget {
  Function startRecording;
  Function onStopRecording;
  bool recording;
  Function onSlide;
  Color? micColor;

  MikeWidget({
    super.key,
    required this.startRecording,
    required this.onStopRecording,
    required this.recording,
    required this.onSlide,
    this.micColor,
  });

  @override
  State<MikeWidget> createState() => _MikeWidgetState();
}

class _MikeWidgetState extends State<MikeWidget> {
  double xTranslate = 0;
  double _buttonSize = 35;
  bool canceled = false;

  onStopRecording() {
    setState(() {
      xTranslate = 0;
    });
    _buttonSize = 35;

    EasyThrottle.throttle('audio_debounce', const Duration(milliseconds: 500),
        () {
      widget.onStopRecording(canceled);
    });
  }

  get buttonSize => _buttonSize;

  onStartedRecording() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(amplitude: 50, duration: 100);
    }
    canceled = false;
    _buttonSize = 75;
    widget.startRecording();
  }

  @override
  void didUpdateWidget(covariant MikeWidget oldWidget) {
    // TODO: implement didUpdateWidget
    super.didUpdateWidget(oldWidget);
    if (!widget.recording) {
      setState(() {
        xTranslate = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Transform.translate(
      offset: Offset(xTranslate, 0),
      child: GestureDetector(
        onTapDown: (TapDownDetails details) {
          onStartedRecording();
        },
        onPanEnd: (DragEndDetails details) {
          onStopRecording();
        },
        onTapUp: (TapUpDetails details) {
          onStopRecording();
        },
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          if (details.delta.dx > 0) {
            return;
          }
          if (details.localPosition.dx <
              -MediaQuery.of(context).size.width / 6) {
            canceled = true;
            onStopRecording();
            return;
          }
          widget.onSlide(details.localPosition.dx);
          // setState(() {
          //   xTranslate = details.localPosition.dx;
          // });
        },
        onHorizontalDragCancel: () {
          onStopRecording();
        },
        onHorizontalDragEnd: (DragEndDetails details) {
          onStopRecording();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(.1),
                blurRadius: 5,
                spreadRadius: 5,
              )
            ],
            borderRadius: const BorderRadius.all(Radius.circular(50)),
            color: widget.micColor ?? theme.colorScheme.primary,
          ),
          padding: const EdgeInsets.all(5),
          child: Icon(
            Icons.mic,
            size: 25,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}

class MicroPhonePermissionException implements Exception {}
