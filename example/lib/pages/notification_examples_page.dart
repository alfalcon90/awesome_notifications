import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

import 'package:awesome_notifications_example/main.dart';
import 'package:awesome_notifications_example/routes.dart';
import 'package:awesome_notifications_example/utils/media_player_central.dart';
import 'package:awesome_notifications_example/utils/notification_util.dart';

import 'package:awesome_notifications_example/common_widgets/check_button.dart';
import 'package:awesome_notifications_example/common_widgets/remarkble_text.dart';
import 'package:awesome_notifications_example/common_widgets/service_control_panel.dart';
import 'package:awesome_notifications_example/common_widgets/simple_button.dart';
import 'package:awesome_notifications_example/common_widgets/text_divisor.dart';
import 'package:awesome_notifications_example/common_widgets/text_note.dart';

class NotificationExamplesPage extends StatefulWidget {

  @override
  _NotificationExamplesPageState createState() => _NotificationExamplesPageState();
}

class _NotificationExamplesPageState extends State<NotificationExamplesPage> {

  String _firebaseAppToken = '';
  String _oneSignalToken = '';

  MediaQueryData mediaQuery;

  bool delayLEDTests = false;
  DateTime _pickedDate;
  TimeOfDay _pickedTime;

  String packageName = 'me.carda.awesome_notifications_example';

  Future<bool> pickScheduleDate(BuildContext context) async {
    TimeOfDay timeOfDay;
    DateTime newDate = await showDatePicker(
        context: context,
        initialDate: _pickedDate ?? DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(Duration(days: 365))
    );

    if(newDate!= null){

      timeOfDay = await showTimePicker(
        context: context,
        initialTime: _pickedTime ?? TimeOfDay.now(),
      );

      if(timeOfDay != null && (_pickedDate != newDate || _pickedTime != timeOfDay)){
        setState(() {
          _pickedTime = timeOfDay;
          _pickedDate = DateTime(newDate.year, newDate.month, newDate.day, timeOfDay.hour, timeOfDay.minute);
        });
        return true;
      }
      return false;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();

    // this is not part of notification system, but media player simulator instead
    MediaPlayerCentral.mediaStream.listen((media) {

      switch(MediaPlayerCentral.mediaLifeCycle){

        case MediaLifeCycle.Stopped:
          cancelNotification(100);
          break;

        case MediaLifeCycle.Paused:
          updateNotificationMediaPlayer(100, media);
          break;

        case MediaLifeCycle.Playing:
          updateNotificationMediaPlayer(100, media);
          break;
      }

    });

    // If you pretend to use the firebase service, you need to initialize it
    // getting a valid token
    initializeFirebaseService();

    AwesomeNotifications().createdStream.listen(
        (receivedNotification){
          String createdSourceText = AssertUtils.toSimpleEnumString(receivedNotification.createdSource);
          Fluttertoast.showToast(msg: '$createdSourceText notification created');
        }
    );

    AwesomeNotifications().displayedStream.listen(
        (receivedNotification){
          String createdSourceText = AssertUtils.toSimpleEnumString(receivedNotification.createdSource);
          Fluttertoast.showToast(msg: '$createdSourceText notification displayed');
        }
    );

    AwesomeNotifications().actionStream.listen(
        (receivedNotification){

          if(!StringUtils.isNullOrEmpty(receivedNotification.buttonKeyInput)){
            processInputTextReceived(receivedNotification);
          }
          else if(
            !StringUtils.isNullOrEmpty(receivedNotification.buttonKeyPressed) &&
            receivedNotification.buttonKeyPressed.startsWith('MEDIA_')
          ) {
            processMediaControls(receivedNotification);
          }
          else {
            processDefaultActionReceived(receivedNotification);
          }

        }
    );
  }

  void processDefaultActionReceived(ReceivedAction receivedNotification) {

      Fluttertoast.showToast(msg: 'Action received');

      String targetPage;

      // Avoid to reopen the media page if is already opened
      if(receivedNotification.channelKey == 'media_player'){

        targetPage = PAGE_MEDIA_DETAILS;
        if(Navigator.of(context).isCurrent(PAGE_MEDIA_DETAILS))
          return;
      }
      else {
        targetPage = PAGE_NOTIFICATION_DETAILS;
      }

      // Avoid to open the notification details page over another details page already opened
      Navigator.pushNamedAndRemoveUntil(
          context,
          targetPage,
              (route) => (route.settings.name != targetPage) || route.isFirst,
          arguments: receivedNotification
      );

  }

  void processInputTextReceived(ReceivedAction receivedNotification) {
    Fluttertoast.showToast(msg: 'Msg: '+receivedNotification.buttonKeyInput, backgroundColor: App.mainColor, textColor: Colors.white);
  }

  void processMediaControls(actionReceived){

      switch(actionReceived.buttonKeyPressed){

        case 'MEDIA_CLOSE':
          MediaPlayerCentral.stop();
          break;

        case 'MEDIA_PLAY':
        case 'MEDIA_PAUSE':
          MediaPlayerCentral.playPause();
          break;

        case 'MEDIA_PREV':
          MediaPlayerCentral.previousMedia();
          break;

        case 'MEDIA_NEXT':
          MediaPlayerCentral.nextMedia();
          break;

        default:
          break;
      }

      Fluttertoast.showToast(msg: 'Media: '+actionReceived.buttonKeyPressed.replaceFirst('MEDIA_', ''), backgroundColor: App.mainColor, textColor: Colors.white);
  }

  @override
  void dispose() {
    AwesomeNotifications().createdSink.close();
    AwesomeNotifications().displayedSink.close();
    AwesomeNotifications().actionSink.close();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initializeFirebaseService() async {
    String firebaseAppToken;
    bool isFirebaseAvailable;

    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      isFirebaseAvailable = await AwesomeNotifications().isFirebaseAvailable;

      if(isFirebaseAvailable){
        try {
          firebaseAppToken = await AwesomeNotifications().firebaseAppToken;
          debugPrint('Firebase token: $firebaseAppToken');
        } on PlatformException {
          firebaseAppToken = null;
          debugPrint('Firebase failed to get token');
        }
      }
      else {
        firebaseAppToken = null;
        debugPrint('Firebase is not available on this project');
      }

    } on PlatformException {
      isFirebaseAvailable = false;
      firebaseAppToken = 'Firebase is not available on this project';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted){
      _firebaseAppToken = firebaseAppToken;
      return;
    }

    setState(() {
      _firebaseAppToken = firebaseAppToken;
    });
  }

  @override
  Widget build(BuildContext context) {

    mediaQuery = MediaQuery.of(context);
    ThemeData themeData = Theme.of(context);

    return Scaffold(

      appBar: AppBar(
        centerTitle: false,
        title: Image.asset(
            'assets/images/awesome-notifications-logo-color.png',
            width: mediaQuery.size.width * 0.6
        ),//Text('Local Notification Example App', style: TextStyle(fontSize: 20)),
        elevation: 10,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric( horizontal: 15, vertical:8 ),
        children: <Widget>[

          /* ******************************************************************** */

          TextDivisor( title: 'Package name' ),
          RemarkableText( text: packageName, color: themeData.primaryColor),
          SimpleButton(
              'Copy package name',
              onPressed: (){
                Clipboard.setData(ClipboardData(text: packageName));
              }
          ),

          /* ******************************************************************** */

          TextDivisor( title: 'Push Service Status' ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              ServiceControlPanel(
                  'Firebase',
                  !StringUtils.isNullOrEmpty(_firebaseAppToken),
                  themeData,
                  onPressed: () =>
                      Navigator.pushNamed(context, PAGE_FIREBASE_TESTS, arguments: _firebaseAppToken )
              ),
              /*
              /// TODO MISSING IMPLEMENTATION FOR ONE SIGNAL
              ServiceControlPanel(
                  'One Signal',
                  _oneSignalToken.isNotEmpty,
                  themeData
              ),
              */
            ],
          ),
          TextNote(
              'Is not necessary to use Firebase (or other) services to use local notifications. But all they can be used simultaneously.'
          ),

          /* ******************************************************************** */

          TextDivisor(title: 'Media Player'),
          TextNote(
              'The media player its just emulated and was built to help me to check if the notification media control contemplates the dev demands, such as sync state, etc.' '\n\n'
                  'The layout itself was built just for fun, you can use it as you wish for.' '\n\n'
                  'ATENTION: There is no media reproducing in any place, its just a Timer to pretend a time passing.'
          ),
          SimpleButton(
              'Show media player',
              onPressed: () => Navigator.pushNamed(context, PAGE_MEDIA_DETAILS)
          ),
          SimpleButton(
              'Cancel notification',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: () => cancelNotification(100)
          ),

          /* ******************************************************************** */

          TextDivisor( title: 'Basic Notifications' ),
          TextNote(
              'A simple and fast notification to fresh start.\n\n'
              'Tap on notification when it appears on your system tray to go to Details page.'
          ),
          SimpleButton(
              'Show the most basic notification',
              onPressed: () => showBasicNotification(1)
          ),
          SimpleButton(
              'Show notification with payload',
              onPressed: () => showNotificationWithPayloadContent(1)
          ),
          SimpleButton(
              'Show notification without body content',
              onPressed: () => showNotificationWithoutBody(1)
          ),
          SimpleButton(
              'Show notification without title content',
              onPressed: () => showNotificationWithoutTitle(1)
          ),
          SimpleButton(
              'Send background notification',
              onPressed: () => sendBackgroundNotification(1)
          ),
          SimpleButton(
              'Cancel the basic notification',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: () => cancelNotification(1)
          ),

          /* ******************************************************************** */

          TextDivisor(title: 'Big Picture Notifications'),
          TextNote(
              'To show any images on notification, at any place, you need to include the respective source prefix before the path.' '\n\n'
              'Images can be defined using 4 prefix types:' '\n\n'
                  '* Asset: images access through Flutter asset method.\n\t Example:\n\t asset://path/to/image-asset.png'
                  '\n\n'
                  '* Network: images access through internet connection.\n\t Example:\n\t http(s)://url.com/to/image-asset.png'
                  '\n\n'
                  '* File: images access through files stored on device.\n\t Example:\n\t file://path/to/image-asset.png'
                  '\n\n'
                  '* Resource: images access through drawable native resources.\n\t Example:\n\t resource://url.com/to/image-asset.png'
          ),
          SimpleButton(
              'Show large icon notification',
              onPressed: () => showLargeIconNotification(2)
          ),
          SimpleButton(
              'Show big picture notification\n(Network Source)',
              onPressed: () => showBigPictureNetworkNotification(2)
          ),
          SimpleButton(
              'Show big picture notification\n(Asset Source)',
              onPressed: () => showBigPictureAssetNotification(2)
          ),
          SimpleButton(
              'Show big picture notification\n(File Source)',
              onPressed: () => showBigPictureFileNotification(2)
          ),
          SimpleButton(
              'Show big picture notification\n(Resource Source)',
              onPressed: () => showBigPictureResourceNotification(2)
          ),
          SimpleButton(
              'Show big picture and\nlarge icon notification simultaneously',
              onPressed: () => showBigPictureAndLargeIconNotification(2)
          ),
          SimpleButton(
              'Show big picture notification,\n but hide large icon on expand',
              onPressed: () => showBigPictureNotificationHideExpandedLargeIcon(2)
          ),
          SimpleButton(
              'Cancel notification',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: () => cancelNotification(2)
          ),

          /* ******************************************************************** */

          TextDivisor( title: 'Action Buttons' ),
          TextNote(
              'Action buttons can be used in four types:' '\n\n'
                  '* Default: after user taps, the notification bar is closed and an action event is fired.'
                  '\n\n'
                  '* InputField: after user taps, a input text field is displayed to capture input by the user.'
                  '\n\n'
                  '* DisabledAction: after user taps, the notification bar is closed, but the respective action event is not fired.'
                  '\n\n'
                  '* KeepOnTop: after user taps, the notification bar is not closed, but an action event is fired.'
          ),
          TextNote(
              'Since Android Nougat, icons are only displayed on media layout. The icon media needs to be a native resource type.'
          ),
          SimpleButton(
              'Show notification with\nsimple Action buttons (one disabled)',
              onPressed: () => showNotificationWithActionButtons(3)
          ),
          SimpleButton(
              'Show notification with\nIcons and Action buttons',
              onPressed: () => showNotificationWithIconsAndActionButtons(3)
          ),
          SimpleButton(
              'Show notification with\nReply and Action button',
              onPressed: () => showNotificationWithActionButtonsAndReply(3)
          ),
          SimpleButton(
              'Show Big picture notification\nwith Action Buttons',
              onPressed: () => showBigPictureNotificationActionButtons(3)
          ),
          SimpleButton(
              'Show Big picture notification\nwith Reply and Action button',
              onPressed: () => showBigPictureNotificationActionButtonsAndReply(3)
          ),
          SimpleButton(
              'Show Big text notification\nwith Reply and Action button',
              onPressed: () => showBigTextNotificationWithActionAndReply(3)
          ),
          SimpleButton(
              'Cancel notification',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: () => cancelNotification(3)
          ),

          /* ******************************************************************** */

          TextDivisor(title: 'Vibration Patterns'),
          TextNote(
              'The PushNotification plugin has 3 vibration patters as example, but you perfectly can create your own patter.' '\n'
              'The patter is made by a list of big integer, separated between ON and OFF duration in milliseconds.'
          ),
          TextNote(
              'A vibration pattern pre-configured in a channel could be updated at any time using the method PushNotification.setChannel'
          ),
          SimpleButton(
              'Show plain notification with low vibration pattern',
              onPressed: () => showLowVibrationNotification(4)
          ),
          SimpleButton(
              'Show plain notification with medium vibration pattern',
              onPressed: () => showMediumVibrationNotification(4)
          ),
          SimpleButton(
              'Show plain notification with high vibration pattern',
              onPressed: () => showHighVibrationNotification(4)
          ),
          SimpleButton(
              'Show plain notification with custom vibration pattern',
              onPressed: () => showCustomVibrationNotification(4)
          ),
          SimpleButton(
              'Cancel notification',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: () => cancelNotification(4)
          ),

          /* ******************************************************************** */

          TextDivisor(title: 'LEDs and Colors'),
          TextNote('The led colors and the default layout color are independent'),
          TextNote(
              'Some devices need to be locked to activate LED lights.' '\n'
              'If that is your case, please delay the notification to give to you enough time.'),
          CheckButton(
              'Delay notifications for 5 seconds',
              delayLEDTests,
              onPressed: (value){
                setState(() {
                  delayLEDTests = value;
                });
              }
          ),
          SimpleButton(
              'Notification with red text color\nand red LED',
              onPressed: () => redNotification(5, delayLEDTests)
          ),
          SimpleButton(
              'Notification with yellow text color\nand yellow LED',
              onPressed: () => yellowNotification(5, delayLEDTests)
          ),
          SimpleButton(
              'Notification with green text color\nand green LED',
              onPressed: () => greenNotification(5, delayLEDTests)
          ),
          SimpleButton(
              'Notification with blue text color\nand blue LED',
              onPressed: () => blueNotification(5, delayLEDTests)
          ),
          SimpleButton(
              'Notification with purple text color\nand purple LED',
              onPressed: () => purpleNotification(5, delayLEDTests)
          ),
          SimpleButton(
              'Cancel notification',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: () => cancelNotification(5)
          ),

          /* ******************************************************************** */

          TextDivisor(title: 'Notification Sound'),
          SimpleButton(
              'Show notification with custom sound',
              onPressed: () => showCustomSoundNotification(6)
          ),
          SimpleButton(
              'Cancel notification',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: () => cancelNotification(6)
          ),

          /* ******************************************************************** */

          TextDivisor(title: 'Silenced Notifications'),
          SimpleButton(
              'Show notification with no sound',
              onPressed: () => showNotificationWithNoSound(7)
          ),
          SimpleButton(
              'Cancel notification',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: () => cancelNotification(7)
          ),

          /* ******************************************************************** */

          TextDivisor( title: 'Scheduled Notifications' ),
          SimpleButton(
              'Schedule notification',
              onPressed: () async {
                if(await pickScheduleDate(context)){
                  showNotificationAtScheduleCron(8, _pickedDate);
                }
              }
          ),
          SimpleButton(
            'Show notification at every single minute',
            onPressed: () => repeatMinuteNotification(8),
          ),
          SimpleButton(
            'Show notification at every single minute o\'clock',
            onPressed: () => repeatMinuteNotificationOClock(8),
          ),
          SimpleButton(
            'Show notification only on workweek days\nat 10:00 am (local)',
            onPressed: () => showScheduleAtWorkweekDay10AmLocal(8),
          ),
          SimpleButton(
              'List all active schedules',
              onPressed: () => listScheduledNotifications(context)
          ),
          SimpleButton(
              'Cancel single active schedule',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: () => cancelSchedule(8)
          ),
          SimpleButton(
              'Cancel all active schedules',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: cancelAllSchedules
          ),
          SimpleButton(
              'Cancel notification',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: () => cancelNotification(8)
          ),

          /* ******************************************************************** */

          TextDivisor(title: 'Progress Notifications'),
          SimpleButton(
              'Show indeterminate progress notification',
              onPressed: () => showIndeterminateProgressNotification(9)
          ),
          SimpleButton(
              'Show progress notification - updates every second',
              onPressed: () => showProgressNotification(9)
          ),
          SimpleButton(
              'Cancel notification',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: () => cancelNotification(9)
          ),

          /* ******************************************************************** */

          TextDivisor(title: 'Inbox Notifications'),
          SimpleButton(
            'Show Inbox notification',
            onPressed: () => showInboxNotification(10),
          ),
          SimpleButton(
              'Cancel notification',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: () => cancelNotification(10)
          ),

          /* ******************************************************************** */

          TextDivisor(title: 'Messaging Notifications'),
          SimpleButton(
              'Show Messaging notification\n(Work in progress)',
              onPressed: null // showMessagingNotification(11)
          ),
          SimpleButton(
              'Cancel notification',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: () => cancelNotification(11)
          ),

          /* ******************************************************************** */

          TextDivisor(title: 'Grouped Notifications'),
          SimpleButton(
              'Show grouped notifications',
              onPressed: () => showGroupedNotifications(12)
          ),
          SimpleButton(
              'Cancel notification',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: () => cancelNotification(12)
          ),

          /* ******************************************************************** */
          TextDivisor(),
          SimpleButton(
              'Cancel all active schedules',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: cancelAllSchedules
          ),
          SimpleButton(
              'Cancel all notifications',
              backgroundColor: Colors.red,
              labelColor: Colors.white,
              onPressed: cancelAllNotifications
          ),
        ],
      )
    );
  }
}