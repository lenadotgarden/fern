# Contexte Projet : fern 🌿

## Vision

Fern est une application de productivité haut de gamme, Free and Open Source (FOSS), conçue avec une philosophie "local-first" et "offline-first". Elle fusionne l'interface utilisateur épurée et fluide de Things 3 avec la puissance fonctionnelle (timeblocking, suivi du temps) de SuperProductivity.

## Principes Directeurs de Développement

1. **Zéro Bug par le Design** : Utilisation intensive du système de types de Rust pour rendre les états invalides impossibles à compiler.
2. **Test-Driven Development (TDD)** : Chaque règle métier dans le dossier `core/` doit posséder son test unitaire associé avant d'être considérée comme terminée.
3. **Séparation Stricte des Responsabilités** : Le frontend (SwiftUI / Tauri) ne contient aucune logique métier. Il ne fait qu'afficher les données fournies par les fonctions du cœur Rust.
4. **Local-First Pur** : Pas de dépendance obligatoire à un serveur cloud. Le stockage se fait dans un fichier SQLite local avec identifiants UUIDv7 et soft-deletes pour assurer une synchronisation future fluide.

## Spécification des Données Initiales

- **Area** : ID (UUIDv7), Titre, Notes.
- **Project** : ID (UUIDv7), AreaID (Optionnel), Titre, Notes, Deadline, Status (Active, Someday, Logbook, Trash).
- **Task** : ID (UUIDv7), ProjectID (Optionnel), AreaID (Optionnel), Titre, Notes, StartDate, Deadline, EstimatedTime (min), SpentTime (min), Status (Inbox, Active, Logbook, Trash)
