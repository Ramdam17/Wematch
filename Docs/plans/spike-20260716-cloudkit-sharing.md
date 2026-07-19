# Spike — CloudKit private DB + CKShare pour le graphe social (plan 1.2)

**Date:** 2026-07-16 · **Statut:** CLOS sans exécution — décision Rémy 2026-07-16 : Firestore
pour le graphe social (voir change log du plan reboot). Ce document reste la référence
du "pourquoi pas CloudKit partagé" et le protocole resterait valide si la question rouvrait.
**Base:** recherche sourcée (Apple docs, WWDC, samples, retour de production Tact 2026-05).
Références complètes en bas.

## Faits établis par la recherche (sans exécuter le spike)

1. **Personne ne peut écrire dans la private DB d'autrui.** La `sharedCloudDatabase` est une
   vue sur des zones vivant chez leur propriétaire. Tout pattern "inbox" (A livre un record
   à B : FriendRequest, JoinRequest, InboxMessage) passe par une **zone partagée en
   `.readWrite`** que B doit avoir partagée à A au préalable.
2. **La user discoverability est morte** (dépréciée iOS 17, sans remplacement) : pas de
   recherche d'utilisateur par email dans CloudKit. Un annuaire `UserProfile` minimal doit
   rester en public DB, et l'URL d'invitation CKShare doit voyager **hors CloudKit**.
   → L'architecture serait donc **hybride de toute façon** : le canal de transport naturel
   des URLs de share est… le Firebase RTDB déjà en place.
3. **Acceptation programmatique possible** sans share sheet Apple :
   `CKFetchShareMetadataOperation(shareURLs:)` → `CKAcceptSharesOperation`. Côté réception
   SwiftUI, toujours pas de handler natif (SceneDelegate requis) — mais l'acceptation par
   URL contourne ce point.
4. **Zone sharing** (1 groupe = 1 zone custom chez l'admin, `CKShare(recordZoneID:)`) est le
   bon fit pour Group : limite ~100 participants/share (chiffre communautaire) vs 20 membres.
5. **Notifications dégradées en shared DB** : ni `CKQuerySubscription` ni
   `CKRecordZoneSubscription` — seule `CKDatabaseSubscription` + delta fetch. Retour de
   production (Tact, app de chat 100 % CloudKit, 2026-05) : pushes silencieux "trop peu
   fiables", doublons, console cassée avec Advanced Data Protection.
6. **Alternative Firestore** : sous le même Firebase Auth (étape 1.1 en cours), les rules
   par document donnent la sémantique destinataire exacte (`request.auth.uid ==
   resource.data.recipientID`) — le pattern inbox devient trivial. Ordre de grandeur :
   jours vs semaines. Coût : pas de sortie de l'écosystème Google (mais RTDB y est déjà),
   privacy story inférieure à CloudKit.

## Hypothèse la plus risquée (ce que le spike doit prouver)

La **chaîne complète sans UI Apple**, jamais documentée bout-en-bout sur iOS 26 :
B accepte un share depuis une URL brute → écrit en `.readWrite` dans la zone de A →
A est notifié (`CKDatabaseSubscription`) dans un délai utilisable.

## Protocole (2 comptes iCloud, container jetable, harness séparé — PAS dans Wematch)

1. Compte A : zone custom + `CKShare(recordZoneID:)` `.readWrite` → récupérer `share.url`.
2. Transport de l'URL par copier-coller (simule Firebase).
3. Compte B : fetch metadata → acceptation programmatique → `fetchAllRecordZones` sur
   `sharedCloudDatabase` → écrire un record `InboxMessage` dans la zone.
4. Compte A : subscription + delta fetch → lire le message.
5. A révoque B (`removeParticipant`) → observer côté B.

**Mesures** (~20 essais) : latence création→acceptation ; latence écriture→notification→
lecture (médiane + pire cas, push silencieux vs visible) ; taux d'échec par opération.

**Critères de sortie** : acceptation sans share sheet OK sur iOS 26 ; écriture participant
OK ; notification médiane < ~30 s (ou polling acceptable) ; révocation propre.
**Si un maillon casse** → le pattern inbox CloudKit est fermé par la donnée ; la
recommandation bascule sur **Firestore pour le graphe social** (CloudKit conservé
éventuellement pour les données personnelles).

## Sources

Apple: Sharing CloudKit Data · Remote Records · CKFetchShareMetadataOperation ·
CKAcceptSharesOperation · CKShareTransferRepresentation · sample-cloudkit-sharing ·
sample-cloudkit-zonesharing · WWDC21 10015 · Tech Talk 10874 ·
forums 744720 (discoverability) / 96831 (limites) / 656625 (SwiftUI acceptance) ·
Tact "CloudKit bugs" (blog.justtact.com, 2026-05) · Swift with Majid (zone sharing) ·
contagious.dev (sharing tips)
