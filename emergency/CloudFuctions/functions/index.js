const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp(functions.config().functions);
var newData;
/*jshint eqeqeq: true */
exports.messageTrigger = functions.firestore.document('Message/{messageId}').onCreate(async (snapshot, context) => {
    //
    if (snapshot.empty) {
        console.log('No Devices');
        return;
    }

    newData = snapshot.data();
    const deviceIdTokens = await admin
        .firestore()
        .collection('Tokens')
        .get();

    var tokens = [];
    for (var t of deviceIdTokens.docs) {
        // debug
        if (t.data().location === newData.location && t.data().mode && newData.token !== t.data().device_token && (t.data().user.includes('user') || newData.ms.includes(t.data().user)) ){
            tokens.push(t.data().device_token);
        }
    }

    var payload = {
        notification: {
            title: 'Emergency',
            body: 'Help!!',
            sound: 'default',
        },
        data: {
            message: newData.ms,
            click_action: 'FLUTTER_NOTIFICATION_CLICK'
        },
    };

    try {
        const response = await admin.messaging().sendToDevice(tokens, payload);
        console.log('Notification sent successfully');
    } catch (err) {
        console.log(err);
    }
});

// // Create and Deploy Your First Cloud Functions
// // https://firebase.google.com/docs/functions/write-firebase-functions
//
// exports.helloWorld = functions.https.onRequest((request, response) => {
//   functions.logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
