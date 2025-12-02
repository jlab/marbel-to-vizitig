Praktikum: Visualisierung von De-Bruijn-Graphen

Ziel des Praktikums war es, Edge-Coverage-Informationen aus einer  .gfa-Datei zu extrahieren und diese Informatione in der Vizitig-Weboberfläche visuell darzustellen. 
Dazu wurde die bestehende Pipeline erweitert und das Vizitig-Frontend sowie das Backend angepasst. 

In diesem Repository wird dokumentiert, wie die Edge-Coverage-Informationen: 
	- aus der .gfa-Datei extrahiert, 
	- in die Vizitig-Datenbank integriert und 
	- im Vizitig-Frontend angezeigt werden. 

Während des Projektens wurden folgende Skripte verändert oder erweitert: 
	- 3-make_llist.sh
	- marbeel2vizitg.sh 
	- gfa2vizit.py
	- vizitig/api/main.py
	- vizitig/data/site/js/application.js 
	- vizitg/data/site/js/d3_viz.js 
	- vizitig/data/site/js/viz_actions/d3_actions.js 

Neu erstellt wurde der folgende Skript: add_edge_coverage_to_db.py. Die Aufgabe von diesem Skript ist die Extraktion von Edge-Coverage-Informationen aus der .gfa-Datei und die Eintragung diese Daten in die SQL-Datenbank edge_data2. 

Was machen die modifizierten Vizitig-Skripte? 
	- main.py -> Implementiert einen neuen API-Endpoint und liest die Edge-Coverage-Informationen aus der SQl-Datenbank
	- application.js -> Lädt Edge-Coverage-Informationen einmalig beim Starten des Graphen über die API und speichert die Edge-Coverage-Informationen strukturier in Maps, sodass sie von den Actions genutzt werden können. 
	- d3_viz.js -> registriert die neue Viewer-Option "ShowEdgeCoverage" und koordiniert die Darstellung.
	- d3_actions.js -> implementiert die Action ShowEdgeCoverage: färbt die Kanten mit roter Farbe und zeigt die Edge-Coverage-Informatioen als Text für ausgehende Kanten unterhalb der Knoten an. 

Was muss vor der Ausführung der Pipeline beachten? 
	- alle Pfade in marbel2vizitig.sh sollen überprüft werden und angepasst werden, falls Bedarf dafür besteht. 
	- die modifizierte Version von Vizitig soll installiert werden.

Was kann noch verbessert werden? 
Aktuell werden die Edge-Coverage-Information unter den Knoten angezeigt. Man soll die Möglichkeit herausfinden, wie man diese Information über den Kanten darstellen kann? 
