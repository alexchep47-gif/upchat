# Notifications UpChat

UpChat initialise les notifications locales sans demander d’autorisation au démarrage. La demande est déclenchée uniquement par l’action **Réglages → Notifications → Autoriser les notifications**.

Lorsqu’un message Signal est reçu alors que le processus UpChat fonctionne, une notification locale est affichée. Le contenu est masqué par défaut et affiche seulement « Nouveau message ». L’utilisateur peut activer l’aperçu, le son et la vibration séparément.

La proximité Bluetooth et le relais mesh ne peuvent pas réveiller de manière fiable l’application lorsqu’elle est terminée, en particulier sur iOS. Les notifications distantes en arrière-plan nécessitent une étape séparée avec Firebase Cloud Messaging, APNs, les clés de production et une autorisation explicite de l’utilisateur. Cette limite est conservée volontairement : aucune fausse promesse de notification hors ligne n’est faite.
