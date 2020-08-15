import 'dart:async';
import 'dart:math';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';

import 'package:flutter_tts/flutter_tts.dart';

import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

import 'package:permission_handler/permission_handler.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

enum TtsState { playing, stopped, paused, continued }

class _MyAppState extends State<MyApp> {
  FlutterTts flutterTts;

  dynamic languages;
  String language;
  double volume = 0.5;
  double pitch = 1.0;
  double rate = 0.5;

  String _newVoiceText;

  TtsState ttsState = TtsState.stopped;

  bool _hasSpeech = false;
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  String lastWords = "";
  String lastError = "";
  String lastStatus = "";
  String _currentLocaleId = "";
  List<LocaleName> _localeNames = [];
  final SpeechToText speech = SpeechToText();

  get isPlaying => ttsState == TtsState.playing;

  get isStopped => ttsState == TtsState.stopped;

  get isPaused => ttsState == TtsState.paused;

  get isContinued => ttsState == TtsState.continued;

  @override
  initState() {
    super.initState();
    initTts();
  }

  initTts() {
    flutterTts = FlutterTts();

    _getLanguages();

    if (!kIsWeb) {
      if (Platform.isAndroid) {
        _getEngines();
      }
    }

    flutterTts.setStartHandler(() {
      setState(() {
        print("Playing");
        ttsState = TtsState.playing;
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        print("Complete");
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setCancelHandler(() {
      setState(() {
        print("Cancel");
        ttsState = TtsState.stopped;
      });
    });

    if (kIsWeb || Platform.isIOS) {
      flutterTts.setPauseHandler(() {
        setState(() {
          print("Paused");
          ttsState = TtsState.paused;
        });
      });

      flutterTts.setContinueHandler(() {
        setState(() {
          print("Continued");
          ttsState = TtsState.continued;
        });
      });
    }

    flutterTts.setErrorHandler((msg) {
      setState(() {
        print("error: $msg");
        ttsState = TtsState.stopped;
      });
    });
  }

  Future _getLanguages() async {
    languages = await flutterTts.getLanguages;
    if (languages != null) setState(() => languages);
  }

  Future _getEngines() async {
    var engines = await flutterTts.getEngines;
    if (engines != null) {
      for (dynamic engine in engines) {
        print(engine);
      }
    }
  }

  Future _speak() async {
    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);

    if (_newVoiceText != null) {
      if (_newVoiceText.isNotEmpty) {
        var result = await flutterTts.speak(_newVoiceText);
        if (result == 1) setState(() => ttsState = TtsState.playing);
      }
    }
  }

  Future _stop() async {
    var result = await flutterTts.stop();
    if (result == 1) setState(() => ttsState = TtsState.stopped);
  }

  Future _pause() async {
    var result = await flutterTts.pause();
    if (result == 1) setState(() => ttsState = TtsState.paused);
  }

  @override
  void dispose() {
    super.dispose();
    flutterTts.stop();
  }

  List<DropdownMenuItem<String>> getLanguageDropDownMenuItems() {
    var items = List<DropdownMenuItem<String>>();
    for (dynamic type in languages) {
      items.add(
          DropdownMenuItem(value: type as String, child: Text(type as String)));
    }
    return items;
  }

  void changedLanguageDropDownItem(String selectedType) {
    setState(() {
      language = selectedType;
      flutterTts.setLanguage(language);
    });
  }

  void _onChange(String text) {
    setState(() {
      _newVoiceText = text;
    });
  }

  Future<void> initSpeechState() async {
    PermissionStatus _hasSpeechPerms = await Permission.speech.request();
    print(_hasSpeechPerms);
    bool hasSpeech = await speech.initialize(
        onError: errorListener, onStatus: statusListener);
    if (hasSpeech) {
      print('has Speech');
      _localeNames = await speech.locales();
      print(_localeNames);

      var systemLocale = await speech.systemLocale();
      _currentLocaleId = systemLocale.localeId;
      print(_currentLocaleId);
    }

    if (!mounted) return;

    setState(() {
      _hasSpeech = hasSpeech;
    });
  }

  void startListening() {
    lastWords = "";
    lastError = "";
    speech.listen(
        onResult: resultListener,
        listenFor: Duration(seconds: 10),
        localeId: _currentLocaleId,
        onSoundLevelChange: soundLevelListener,
        cancelOnError: true,
        partialResults: true,
        onDevice: true,
        listenMode: ListenMode.confirmation);
    setState(() {});
  }

  void stopListening() {
    speech.stop();
    setState(() {
      level = 0.0;
    });
  }

  void cancelListening() {
    speech.cancel();
    setState(() {
      level = 0.0;
    });
  }

  void resultListener(SpeechRecognitionResult result) {
    setState(() {
      lastWords = "${result.recognizedWords} - ${result.finalResult}";
    });
  }

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);
    // print("sound level $level: $minSoundLevel - $maxSoundLevel ");
    setState(() {
      this.level = level;
    });
  }

  void errorListener(SpeechRecognitionError error) {
    // print("Received error status: $error, listening: ${speech.isListening}");
    setState(() {
      lastError = "${error.errorMsg} - ${error.permanent}";
      print(lastError);
    });
  }

  void statusListener(String status) {
    // print(
    // "Received listener status: $status, listening: ${speech.isListening}");
    setState(() {
      lastStatus = "$status";
    });
  }

  _switchLang(selectedVal) {
    setState(() {
      _currentLocaleId = selectedVal;
    });
    print(selectedVal);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            bottom: TabBar(
              tabs: [
                Tab(icon: Icon(Icons.record_voice_over)),
                Tab(icon: Icon(Icons.keyboard_voice)),
              ],
            ),
            title: Text('Flutter TTS and Speech'),
          ),
          body: TabBarView(
            children: [
              _ttsMain(),
              _voiceRecognition()
              // Icon(Icons.directions_transit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ttsMain() => Padding(
      padding: new EdgeInsets.all(8.0),
      child: Column(children: [
        _inputSection(),
        _btnSection(),
        languages != null ? _languageDropDownSection() : Text(""),
        _buildSliders(),
      ]));

  Widget _voiceRecognition() => Column(children: [
        Center(
          child: Text(
            'Speech recognition available',
            style: TextStyle(fontSize: 22.0),
          ),
        ),
        Container(
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  FlatButton(
                    child: Text('Initialize'),
                    onPressed: _hasSpeech ? null : initSpeechState,
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  FlatButton(
                    child: Text('Start'),
                    onPressed: !_hasSpeech || speech.isListening
                        ? null
                        : startListening,
                  ),
                  FlatButton(
                    child: Text('Stop'),
                    onPressed: speech.isListening ? stopListening : null,
                  ),
                  FlatButton(
                    child: Text('Cancel'),
                    onPressed: speech.isListening ? cancelListening : null,
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  DropdownButton(
                    onChanged: (selectedVal) => _switchLang(selectedVal),
                    value: _currentLocaleId,
                    items: _localeNames
                        .map(
                          (localeName) => DropdownMenuItem(
                            value: localeName.localeId,
                            child: Text(localeName.name),
                          ),
                        )
                        .toList(),
                  ),
                ],
              )
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: Column(
            children: <Widget>[
              Center(
                child: Text(
                  'Recognized Words',
                  style: TextStyle(fontSize: 22.0),
                ),
              ),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    Container(
                      color: Theme.of(context).selectedRowColor,
                      child: Center(
                        child: Text(
                          lastWords,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      bottom: 10,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                  blurRadius: .26,
                                  spreadRadius: level * 1.5,
                                  color: Colors.black.withOpacity(.05))
                            ],
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(50)),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.mic),
                            onPressed: startListening,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Column(
            children: <Widget>[
              Center(
                child: Text(
                  'Error Status',
                  style: TextStyle(fontSize: 22.0),
                ),
              ),
              Center(
                child: Text(lastError),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          color: Theme.of(context).backgroundColor,
          child: Center(
            child: speech.isListening
                ? Text(
                    "I'm listening...",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  )
                : Text(
                    'Not listening',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ]);

  Widget _inputSection() => Container(
      alignment: Alignment.topCenter,
      padding: EdgeInsets.only(top: 25.0, left: 25.0, right: 25.0),
      child: TextField(
        onChanged: (String value) {
          _onChange(value);
        },
      ));

  Widget _btnSection() {
    if (!kIsWeb && Platform.isAndroid) {
      return Container(
          padding: EdgeInsets.only(top: 50.0),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildButtonColumn(Colors.green, Colors.greenAccent,
                Icons.play_arrow, 'PLAY', _speak),
            _buildButtonColumn(
                Colors.red, Colors.redAccent, Icons.stop, 'STOP', _stop),
          ]));
    } else {
      return Container(
          padding: EdgeInsets.only(top: 50.0),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _buildButtonColumn(Colors.green, Colors.greenAccent,
                Icons.play_arrow, 'PLAY', _speak),
            _buildButtonColumn(
                Colors.red, Colors.redAccent, Icons.stop, 'STOP', _stop),
            _buildButtonColumn(
                Colors.blue, Colors.blueAccent, Icons.pause, 'PAUSE', _pause),
          ]));
    }
  }

  Widget _languageDropDownSection() => Container(
      padding: EdgeInsets.only(top: 50.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        DropdownButton(
          value: language,
          items: getLanguageDropDownMenuItems(),
          onChanged: changedLanguageDropDownItem,
        )
      ]));

  Column _buildButtonColumn(Color color, Color splashColor, IconData icon,
      String label, Function func) {
    return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
              icon: Icon(icon),
              color: color,
              splashColor: splashColor,
              onPressed: () => func()),
          Container(
              margin: const EdgeInsets.only(top: 8.0),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w400,
                      color: color)))
        ]);
  }

  Widget _buildSliders() {
    return Column(
      children: [_volume(), _pitch(), _rate()],
    );
  }

  Widget _volume() {
    return Slider(
        value: volume,
        onChanged: (newVolume) {
          setState(() => volume = newVolume);
        },
        min: 0.0,
        max: 1.0,
        divisions: 10,
        label: "Volume: $volume");
  }

  Widget _pitch() {
    return Slider(
      value: pitch,
      onChanged: (newPitch) {
        setState(() => pitch = newPitch);
      },
      min: 0.5,
      max: 2.0,
      divisions: 15,
      label: "Pitch: $pitch",
      activeColor: Colors.red,
    );
  }

  Widget _rate() {
    return Slider(
      value: rate,
      onChanged: (newRate) {
        setState(() => rate = newRate);
      },
      min: 0.0,
      max: 1.0,
      divisions: 10,
      label: "Rate: $rate",
      activeColor: Colors.green,
    );
  }
}
