# Praktikum: Visualisierung von De-Bruijn-Graphen

Ziel des Praktikums war es, Edge-Coverage-Informationen aus einer  .gfa-Datei zu extrahieren und diese Informatione in der Vizitig-Weboberfläche visuell darzustellen. 
Dazu wurde die bestehende Pipeline erweitert und das Vizitig-Frontend sowie das Backend angepasst. 

### In diesem Repository wird dokumentiert, wie die Edge-Coverage-Informationen: 
	- aus der .gfa-Datei extrahiert
	- in die Vizitig-Datenbank integriert und 
	- im Vizitig-Frontend angezeigt werden. 

## Während des Projektens wurden folgende Skripte verändert oder erweitert: 
	- 3-make_llist.sh
	- marbeel2vizitg.sh 
	- gfa2vizit.py
	- vizitig/api/main.py
	- vizitig/data/site/js/application.js 
	- vizitg/data/site/js/d3_viz.js 
	- vizitig/data/site/js/viz_actions/d3_actions.js 

Neu erstellt wurde der folgende Skript: add_edge_coverage_to_db.py. Die Aufgabe von diesem Skript ist die Extraktion von Edge-Coverage-Informationen aus der .gfa-Datei und die Eintragung diese Daten in die Tabelle edge_data2 in der SQL-Datenbank. 

## Was machen die modifizierten Vizitig-Skripte? 
	- main.py -> Implementiert einen neuen API-Endpoint und liest die Edge-Coverage-Informationen aus der SQl-Datenbank
	- application.js -> Lädt Edge-Coverage-Informationen einmalig beim Starten des Graphen über die API und speichert die Edge-Coverage-Informationen strukturier in Maps, sodass sie von den Actions genutzt werden können. 
	- d3_viz.js -> registriert die neue Viewer-Option "ShowEdgeCoverage" und koordiniert die Darstellung.
	- d3_actions.js -> implementiert die Action ShowEdgeCoverage: färbt die Kanten mit roter Farbe und zeigt die Edge-Coverage-Informatioen als Text für ausgehende Kanten unterhalb der Knoten an. 

## Wie die Visualisierung der Edge-Coverage-Informationen funktioniert  und wie werden diese Daten gespeichert und abgerufen? 

### 1. Wie/Wo werden  die Kanten in Vizitig gespeichert? 
SQLite-Datenbank: Die Edge-Coverage-Informationen werden in der SQL-DB gespeichert. Dafür muss man zuerst herausfinden, wo die Graphen nach der Eingabe dieses Befehls "vizitig build <.fa-Datei> -n <Graph-Name> angelegt werden. Wenn Ihr es gefunden habt, dann kann mit den folgenden Befehelen die Liste der Tabellen in der SQL-DB und die Struktur der Tabellen anschauen.
		- sqlite3 <Pfad zu der SQL-DB>
		- .tables -> die Liste der Tabellen werden angezeigt
		- select * from <Tabellen-Name> LImIt 10; -> Die ersten Zeilen der Tabelle werden angezeigt 
		- PRAGMA table_info(tabellenname); -> Struktur einer Tabelle wird angezeigt- 
		- .schema -> zeigt der vollständige Schema von allen Tabellen an.
### 2.Wie werden die Edge-Coverage-Informationen an Backend geliefert? 
Zuerst werden die Edge-Coverage Informationen in die SQL-DB eingetragen.Dies erfolgt mithilfe vom Skript add_edge_coverage_to_db.py. Dieses Skript liest die  dbg_g.gfa-Datei, ordnet Coverage den Kanten zu und schreibt für jede Kante einen Eintrag in edge_data2. Anschließend wird dann im Vizitig-Backend ein neuer FastAPI-Endpoint definiert, welche die Informationen in edges1 und edge_data2 über die KnotenId verbindet. Dieser Schritt ermöglicht alle Edge-Coverage-Daten auf Anfrage bereitzustellen. Backend kann auf dieser Webseite "http://localhost:4242/api/graphs/<name_des_projektes>/edge_coverag" nach dem Aufruf von diesem Befehl <vizitig run> überprüft werden. Auf der Webseite sollte man JSON Liste mit edge_id, source,target,coverage sehen. 
### 3. Wie werden die Edge-Coverage-Informationen an Frontend geliefert? 
Im Frontend ist das Skript application.js für das Laden und Cachen von Daten zuständig. Die Funktion load_edge_coverage ruft den Backend-Endpoint auf,gruppiert alle Coverage-Einträge nach source-Knoten und speichert diese Information in einer Map.   
### 4. Wie werden die Edge-Coverage-Informationen dargestellt? 
Für die Darstellung der Edge-Coverage-Informationen sind d3_viz.js und f3_actions.js zuständig.In d3_viz.js wird die ShowEdgeCoverage als auswählbare Aktion registriert. Im d3_actions.js gibt es zwei Funktionen, die die Kanten mit Coverage deutlich mit roter Farbe hervorheben (transform_edge) und pro Knoten die Coverage Informationen der ausgehenden Kanten als Text anzeigen.
## Was muss vor der Ausführung der Pipeline beachten? 
	- alle Pfade in marbel2vizitig.sh sollen überprüft werden und angepasst werden, falls Bedarf dafür besteht. 
	- die modifizierte Version (https://github.com/jlab/vizitig_clone.git) von Vizitig soll installiert werden.
## Was kann noch verbessert werden? 
Aktuell werden die Edge-Coverage-Information unter den Knoten angezeigt. Man soll die Möglichkeit herausfinden, wie man diese Information über den Kanten darstellen kann? 
