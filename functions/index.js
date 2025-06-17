const functions = require('firebase-functions');
const admin     = require('firebase-admin');
admin.initializeApp();

// — Votre fonction existante d’invitation (inchangée) —
exports.notifyOnInvitation = functions
  .firestore
  .document('invitations/{invId}')
  .onCreate(async (snap, ctx) => {
    const inv = snap.data();
    const recipientId = inv.recipientId;
    const userSnap    = await admin.firestore().collection('users').doc(recipientId).get();
    const token       = userSnap.get('fcmToken');
    if (!token) return null;
    const payload = {
      notification: {
        title: 'Nouvelle invitation !',
        body : `Vous êtes invité·e par ${inv.senderId}`,
      },
      data: {
        challengeId: inv.challengeId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      }
    };
    return admin.messaging().sendToDevice(token, payload);
  });

// — Nouvelle fonction “Mise à jour de l’app” —
exports.notifyAppUpdate = functions.https.onRequest(async (req, res) => {
  // Payload générique pour informer de la mise à jour
  const payload = {
    notification: {
      title: '📱 Mise à jour disponible !',
      body:  'Téléchargez la dernière version de Quiz Commercial dès maintenant.',
    },
    data: {
      url: 'https://play.google.com/store/apps/details?id=com.quiz_commercial2024.quiz_commercial2024&pcampaignid=web_share',
    }
  };

  try {
    // Envoi à tous les abonnés du topic “app_updates”
    const response = await admin.messaging().sendToTopic('app_updates', payload);
    console.log('App update notification sent:', response);
    res.status(200).send('Mis à jour envoyée.');
  } catch (err) {
    console.error('Erreur sendToTopic:', err);
    res.status(500).send(err);
  }
});
