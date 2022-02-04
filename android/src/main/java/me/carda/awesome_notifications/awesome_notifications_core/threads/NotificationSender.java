package me.carda.awesome_notifications.awesome_notifications_core.threads;

import android.app.Notification;
import android.content.Context;
import android.os.AsyncTask;
import android.os.Build;
import android.util.Log;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.List;

import me.carda.awesome_notifications.awesome_notifications_core.AwesomeNotifications;
import me.carda.awesome_notifications.awesome_notifications_core.builders.NotificationBuilder;
import me.carda.awesome_notifications.awesome_notifications_core.enumerators.NotificationLayout;
import me.carda.awesome_notifications.awesome_notifications_core.enumerators.NotificationLifeCycle;
import me.carda.awesome_notifications.awesome_notifications_core.enumerators.NotificationSource;
import me.carda.awesome_notifications.awesome_notifications_core.exceptions.AwesomeNotificationsException;
import me.carda.awesome_notifications.awesome_notifications_core.managers.StatusBarManager;
import me.carda.awesome_notifications.awesome_notifications_core.models.NotificationModel;
import me.carda.awesome_notifications.awesome_notifications_core.models.returnedData.NotificationReceived;
import me.carda.awesome_notifications.awesome_notifications_core.broadcasters.senders.BroadcastSender;
import me.carda.awesome_notifications.awesome_notifications_core.utils.IntegerUtils;
import me.carda.awesome_notifications.awesome_notifications_core.utils.StringUtils;

public class NotificationSender extends AsyncTask<String, Void, NotificationReceived> {

    public static String TAG = "NotificationSender";

    private final WeakReference<Context> wContextReference;

    private final NotificationBuilder notificationBuilder;
    private final NotificationSource createdSource;
    private final NotificationLifeCycle appLifeCycle;

    private NotificationModel notificationModel;

    private Boolean created = false;
    private Boolean displayed = false;

    private long startTime = 0L, endTime = 0L;


    /// FACTORY METHODS BEGIN *********************************

    public static void send(
            Context context,
            NotificationBuilder notificationBuilder,
            NotificationLifeCycle appLifeCycle,
            NotificationModel notificationModel
    ) throws AwesomeNotificationsException {

        NotificationSender.send(
                context,
                notificationBuilder,
                notificationModel.content.createdSource,
                appLifeCycle,
                notificationModel);
    }

    public static void send(
        Context context,
        NotificationBuilder notificationBuilder,
        NotificationSource createdSource,
        NotificationLifeCycle appLifeCycle,
        NotificationModel notificationModel
    ) throws AwesomeNotificationsException {

        if (notificationModel == null )
            throw new AwesomeNotificationsException("Notification cannot be empty or null");

        new NotificationSender(
            context,
            notificationBuilder,
            appLifeCycle,
            createdSource,
            notificationModel
        ).execute();
    }

    private NotificationSender(
            Context context,
            NotificationBuilder notificationBuilder,
            NotificationLifeCycle appLifeCycle,
            NotificationSource createdSource,
            NotificationModel notificationModel
    ){
        this.wContextReference = new WeakReference<>(context);
        this.notificationBuilder = notificationBuilder;
        this.createdSource = createdSource;
        this.appLifeCycle = appLifeCycle;
        this.notificationModel = notificationModel;
        this.startTime = System.nanoTime();
    }

    /// AsyncTask METHODS BEGIN *********************************

    @Override
    protected NotificationReceived doInBackground(String... parameters) {

        try {

            if (notificationModel != null){

                created = notificationModel
                            .content
                            .registerCreatedEvent(
                                appLifeCycle,
                                createdSource);

                displayed = notificationModel
                            .content
                            .registerDisplayedEvent(
                                appLifeCycle);

                if (
                    !StringUtils.isNullOrEmpty(notificationModel.content.title) ||
                    !StringUtils.isNullOrEmpty(notificationModel.content.body)
                ){
                    notificationModel = showNotification(
                            wContextReference.get(),
                            notificationModel);
                }

                // Only save DisplayedMethods if notificationModel was created
                // and displayed successfully
                if(notificationModel != null)
                    return new NotificationReceived(notificationModel.content);
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        notificationModel = null;
        return null;
    }

    @Override
    protected void onPostExecute(NotificationReceived receivedNotification) {

        // Only broadcast if notificationModel is valid
        if(notificationModel != null){

            if(created)
                BroadcastSender.sendBroadcastNotificationCreated(
                    wContextReference.get(),
                    receivedNotification);

            if(displayed)
                BroadcastSender.sendBroadcastNotificationDisplayed(
                    wContextReference.get(),
                    receivedNotification);
        }

        if(this.endTime == 0L)
            this.endTime = System.nanoTime();

        if(AwesomeNotifications.debug){
            long elapsed = (endTime - startTime)/1000000;

            List<String> actionsTookList = new ArrayList<>();
            if(created) actionsTookList.add("created");
            if(displayed) actionsTookList.add("displayed");

            Log.d(TAG, "Notification "+StringUtils.join(actionsTookList.iterator(), " and ")+" in "+elapsed+"ms");
        }
    }

    /// AsyncTask METHODS END *********************************

    public NotificationModel showNotification(Context context, NotificationModel notificationModel) {

        try {

            NotificationLifeCycle lifeCycle = AwesomeNotifications.getApplicationLifeCycle();

            boolean shouldDisplay = true;
            switch (lifeCycle){

                case Background:
                    shouldDisplay = notificationModel.content.displayOnBackground;
                    break;

                case Foreground:
                    shouldDisplay = notificationModel.content.displayOnForeground;
                    break;
            }

            if(shouldDisplay){

                Notification notification =
                        notificationBuilder
                            .createNewAndroidNotification(context, notificationModel);

                if(
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                    notificationModel.content.notificationLayout == NotificationLayout.Default &&
                    StatusBarManager
                        .getInstance(context)
                        .isFirstActiveOnGroupKey(notificationModel.content.groupKey)
                ){
                    NotificationModel pushSummary = _buildSummaryGroupNotification(notificationModel);
                    Notification summaryNotification =
                            notificationBuilder
                                    .createNewAndroidNotification(context, pushSummary);

                    StatusBarManager
                        .getInstance(context)
                        .showNotificationOnStatusBar(pushSummary, summaryNotification);
                }

                StatusBarManager
                        .getInstance(context)
                        .showNotificationOnStatusBar(notificationModel, notification);
            }

            return notificationModel;

        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }

    private NotificationModel _buildSummaryGroupNotification(NotificationModel original){

        NotificationModel pushSummary = notificationModel.ClonePush();

        pushSummary.content.id = IntegerUtils.generateNextRandomId();
        pushSummary.content.notificationLayout = NotificationLayout.Default;
        pushSummary.content.largeIcon = null;
        pushSummary.content.bigPicture = null;
        pushSummary.groupSummary = true;

        return  pushSummary;
    }
}