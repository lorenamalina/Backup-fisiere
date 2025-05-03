#!/bin/bash

##Backup_avansat_de_fișiere - proiect nivel B
##membri: Racolța Claudia Denisa, Răscol Timofte Naomi Denisa, Guiu Lorena Mălina, Beatriz Komaromi, Margău Patricia-Ionela


##se vor salva log-urile in fisierul out.log
FISIERE_LOG="out.log"
exec > >(tee -a "$FISIERE_LOG") 2>&1

##Dacă debug este activat, afișăm loguri de debug
debug_log(){
if [ "$DEBUG" == "on" ]; then
echo "[DEBUG] $1"
fi
}



DEBUG="off"

while getopts ":hud:" opt; do
case ${opt} in
h)
echo "Ajutor:"
echo "-h, --help      Afișează acest mesaj de ajutor"
echo "-u, --usage     Afișează informații despre utilizare"
echo "-d              Activează/dezactivează logurile de debug (default off)"
;;
u)
echo "Utilizare:"
echo "./script.sh [optiuni]"
echo "Opțiuni:"
echo "  -h, --help      Afișează acest mesaj de ajutor"
echo "  -u, --usage     Afișează informații despre utilizare"
echo "  -d on      Activează logurile de debug"
echo "  -d off     Dezactivează logurile de debug"
;;
d)
if [ "$OPTARG" == "on" ]; then
DEBUG="on"
elif [ "$OPTARG" == "off" ]; then
DEBUG="off"
else
echo "Valoare invalidă pentru -d. Folosește 'on' sau 'off'."
fi
;;
*)
echo "Optiune necunoscuta"
;;
esac
done

debug_log "Modul de debugging : $DEBUG"

##1)
f_gasire_fisiere() {
    debug_log "Primeste data specificata de utilizator"
    echo "Introduceți data (în orice format valid):"
    read data_utilizator
    possible_formats=(
        "+%s"               
        "%m/%d/%Y"          
        "%d/%m/%Y"          
        "%Y-%m-%d"         
        "%d-%m-%Y"         
        "%d.%m.%Y"        
        "%B %d, %Y"      
        "%d %B %Y"     
    )

    data_unix=""
    for fmt in "${possible_formats[@]}"; do
        data_unix=$(date -d "$data_utilizator" +"$fmt" 2>/dev/null)
        if [ $? -eq 0 ]; then
            data_unix=$(date -d "$data_utilizator" +%s)
            break
        fi
    done

    if [ -z "$data_unix" ]; then
        echo "Data introdusă este invalidă sau nu poate fi dedusă."
        debug_log "Data introdusă este invalidă: $data_utilizator"
        return
    fi

    debug_log "Introduceți directorul în care să căutăm fișierele"
    echo "Introduceți directorul în care doriți să căutați fișierele:"
    read director

    debug_log "Verificăm dacă directorul există"
    if [ ! -d "$director" ]; then
        echo "Directorul '$director' nu există."
        debug_log "Directorul '$director' nu există."
        return
    fi

    debug_log "Căutăm fișierele mai vechi de data specificată"
    find "$director" -type f -printf "%p %T@\n" | awk -v d="$data_unix" '$2 < d {print $1}'
    debug_log "Lista fișierelor mai vechi a fost generată"
}




##2)
f_mutare_local(){
debug_log "Primeste de la tastatura directorul sursa"
echo "Introduceti directorul sursa:"
read sursa
debug_log "Primeste de la tastatura directorul destinatie"
echo "Introduceti directorul destinatie:"
read destinatie

debug_log "Verificare daca directorul sursa exista"
if [ ! -d "$sursa" ]; then
    echo "Directorul sursa nu exista"
    debug_log "Directorul sursă '$sursa' nu exista"
    return
fi

debug_log "Verificare daca directorul destinatie exista"
if [ ! -d "$destinatie" ]; then
    debug_log "Directorul nu exista, utilizatorul este intrebat daca doreste sa fie creat"
    echo "Directorul destinatie nu exista. Doriti sa-l creati? (y/n)"
    read raspuns
    if [ "$raspuns" == "y" ]; then
        mkdir -p "$destinatie"
        debug_log "Directorul destinatie '$destinatie' a fost creat"
    else
        return
    fi
fi

debug_log "Verificam daca directorul '$sursa' este gol"
if [ "$(ls -A "$sursa")" ]; then
mv "$sursa"/* "$destinatie"
echo "Fisierele din '$sursa' au fost mutate in '$destinatie'."
debug_log "Fisierele au fost mutate cu succes din '$sursa' in '$destinatie'."
else
    echo "Directorul este gol"
    debug_log "Directorul este gol, nu s-au mutat fisiere"
fi
}


##3)
f_mutare_cloud() {
debug_log "Introduceți directorul sursă"
echo "Introduceți directorul sursă:"
read sursa

debug_log "Verificăm dacă directorul sursă există"
if [ ! -d "$sursa" ]; then
    echo "Directorul sursă nu există."
    debug_log "Directorul sursă '$sursa' nu există."
    return
fi

debug_log "Introduceți URL-ul cloud-ului"
echo "Introduceți URL-ul pentru cloud:"
read url_cloud

debug_log "Se încarcă fișierele din '$sursa' către '$url_cloud'"
for file in "$sursa"/*; do
    if [ -f "$file" ]; then
        curl -X POST -F "file=@$file" "$url_cloud" && echo "Fișierul '$file' a fost încărcat cu succes."
        debug_log "Fișierul '$file' a fost încărcat cu succes pe '$url_cloud'"
    fi
done
debug_log "Mutarea fișierelor în cloud s-a încheiat"
}



##4)
f_stergere() {
    debug_log "Primeste de la tastatura calea catre directorul unde se vor sterge fisierele"
    echo "Introduceti calea directorului unde vor fi sterse fisierele mai vechi de 60 de zile:"
    read director

    debug_log "Verificare dacă directorul exista"
    if [ ! -d "$director" ]; then
        echo "Directorul '$director' nu exista"
        debug_log "Directorul '$director' nu exista"
        return
    fi

    debug_log "Configurare comanda cron job"
    cron_job="0 20 * * 1 find \"$director\" -type f -mtime +60 -exec rm -f {} \;"

    debug_log "Verificare existenta cron job"
   
      if crontab -l 2>/dev/null | grep -qF "$cron_job"; then
        echo "Job cron pentru stergerea fisierelor mai vechi de 60 de zile deja exista"
        debug_log "Job cron-ul pentru directorul '$director' exista deja"
        return
    fi

    debug_log "Adaugarea job cron-ului la crontab"
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -

    echo "Job cron-ul a fost configurat pentru stergerea fisierelor mai vechi de 60 de zile în fiecare luni la ora 20:00"
    debug_log "Job cron-ul a fost configurat cu succes pentru directorul '$director'"
}




##5)
f_redenumire(){
debug_log "Primeste de la tastatura calea catre directorul pentru care va redenumii fisierele"
echo "Calea catre director:"
read director

debug_log "Primeste extensia care va fi inlocuita"
echo "Extensie pentru inlocuire:"
read extensie

for file in "$director"/*; do
debug_log "Verificare daca este fisier si daca are deja extensia pe care vrem sa o adaugam"

if [ -f "$file" ]; then
debug_log "Extragem extensia si numele fisierului actual"
extensie_veche="${file##*.}"
nume_fisier="${file%.*}"

if [[ "$extensie_veche" != "$extensie" ]]; then
nume_nou="$nume_fisier.$extensie"
debug_log "Redenumim fișierul '$file' în '$nume_nou'"
mv "$file" "$nume_nou"
echo "Fișierul '$file' a fost redenumit în '$nume_nou'"
debug_log "Fișierul '$file' a fost redenumit cu succes în '$nume_nou'"
else
debug_log "Fișierul '$file' deja are sufixul '.old', nu a fost redenumit"
fi

fi
done
debug_log "Redenumirea fișierelor s-a încheiat"
}

##6
f_editare() {
debug_log "Primeste de la tastatura directorul in care vrem sa editam fisierele"
echo "Introdu directorul:"
read director
debug_log "Verificam existenta directorului"
if [ ! -d "$director" ]; then
echo "Dir nu exista"
debug_log "Fisierul nu exista"
return
fi
debug_log "Editarea fisierelor"
for file in "$director"/*; do
if [ -f "$file" ]; then
if ! grep -q "#### DEPRECATED #####" "$file"; then
echo "#### DEPRECATED #####" >> "$file"
echo "Fisierul '$file' editat"
debug_log "Fisierul a fost editat. In fiecare fisier a fost scris ###DEPRECATED####"
else
echo "Fisierul '$file' a fost deja editat"
debug_log "Fisierul a fost deja editat"
fi
fi
done
}

##7
f_mutare_fisiere_mari(){
echo "Introduce directorul:"
read director
debug_log "Verificare daca dir exista"
if [ ! -d "$director" ]; then
    echo "Dir nu exista"
debug_log "Directorul nu exista"
    return
fi

director_pt_mutat="$director/director_pt_mutat"

mkdir -p "$director_pt_mutat"
debug_log "Mutare fisiere mai mari de 100 MB in dir $director_de_mutat"
find "$director" -maxdepth 1 -type f -size +100M -exec mv {} "$director_pt_mutat" \;

echo "Fisierele mai mari de 100 MB au fost mutate in '$director_pt_mutat'"
debug_log "Fisierele maimari de 100 MB au fost mutate in $director_de_mutat"
}

##8
f_arhivare_si_comprimare() {
    echo "Introduceti calea catre fisierul sau directorul ce se doreste a fi arhivat si comprimat:"
    read entitate
    if [ -d "$entitate" ]; then
        tar -czf "$entitate.tar.gz" "$entitate" && echo "Directorul '$entitate' a fost arhivat si comprimat cu succes."
        debug_log "Directorul '$entitate' a fost arhivat si comprimat."
    elif [ -f "$entitate" ]; then
        gzip -c "$entitate" > "$entitate.gz" && echo "Fisierul '$entitate' a fost arhivat si comprimat cu succes."
        debug_log "Fisierul '$entitate' a fost arhivat si comprimat."
    else
        echo "Fisierul sau directorul nu exista."
        debug_log "Eroare la arhivare si comprimare '$entitate' nu a fost gasit."
    fi
}

##9
f_comparare_entitati() {
    debug_log "Primeste de la utilizator calea catre prima entitate"
    echo "Introduceti calea catre prima entitate (fisier sau director):"
    read entitate1

    debug_log "Primeste de la utilizator calea catre a doua entitate"
    echo "Introduceti calea catre a doua entitate (fisier sau director):"
    read entitate2

    if [ ! -e "$entitate1" ]; then
        echo "Prima entitate nu exista."
        debug_log "Prima entitate '$entitate1' nu exista."
        return
    fi

    if [ ! -e "$entitate2" ]; then
        echo "A doua entitate nu exista."
        debug_log "A doua entitate '$entitate2' nu exista."
        return
    fi

    if [ -f "$entitate1" ] && [ -f "$entitate2" ]; then
        debug_log "Se comapara fisierele '$entitate1' si '$entitate2'"
        diff "$entitate1" "$entitate2" > /dev/null
        if [ $? -eq 0 ]; then
            echo "Fisierele sunt identice."
            debug_log "Fisierele '$entitate1' si '$entitate2' sunt identice."
        else
            echo "Fisierele sunt diferite. Diferentele sunt:"
            diff "$entitate1" "$entitate2"
            debug_log "Diferentele dintre fisierele '$entitate1' si '$entitate2' au fost afisate."
        fi
    elif [ -d "$entitate1" ] && [ -d "$entitate2" ]; then
        debug_log "Comparam directoarele '$entitate1' si '$entitate2'"
        diff -r "$entitate1" "$entitate2" > /dev/null
        if [ $? -eq 0 ]; then
            echo "Directoarele sunt identice."
            debug_log "Directoarele '$entitate1' si '$entitate2' sunt identice."
        else
            echo "Directoarele sunt diferite. Diferentele sunt:"
            diff -r "$entitate1" "$entitate2"
            debug_log "Diferentele dintre directoarele '$entitate1' si '$entitate2' au fost afisate."
        fi
    else
        echo "Unele dintre entitati nu sunt de acelasi tip (fișier sau director)."
        debug_log "Compararea a esuat deoarece entitatile nu sunt de acelasi tip."
    fi
}

##10
cautare_fisiere() {
debug_log "Introducere director"
echo "Introdu directorul: "
read dir
if [[ ! -d "$dir" ]]; then
echo "Dir nu exista"
debug_log "Directorul nu exista"
return
fi
fisiere_gasite=""
while true; do
echo "Cum doresti sa cauti fisierele?"
echo "1. Dupa nume"
echo "2. Dupa dimensiune"
echo "3. Dupa extensie"
echo "4. Opreste cautarea"
echo "Alege optiune: "
read optiune
case $optiune in
1)
debug_log "Introducere nume fisier"
echo "Introdu numele fisierului"
read nume
fisiere_gasite=$(find "$dir" -type f -name "*$nume*")
;;
2)
debug_log "Introducere dimensiune fisier"
echo "Introdu dimensiune fisier:"
echo "1. In bytes"
echo "2. In MB"
echo "3. In GB"
echo "Alege unitatea de masura: "
read unitate
echo "Introdu dimensiunea fisierului: "
read dim

case $unitate in
1)
debug_log "Dimensiune in bytes"
export fisiere_gasite=$(find "$dir" -type f -size +"$dim"c)
;;
2)
debug_log "Dimensiune in MB"
dim_bytes=$((dim * 1024 * 1024))
export fisiere_gasite=$(find "$dir" -type f -size +"$dim_bytes"c)
;;
3)
debug_log "Dimensiune in GB"
dim_bytes=$((dim * 1024 * 1024 * 1024))
fisiere_gasite=$(find "$dir" -type f -size +"$dim_bytes"c)
;;
*)
debug_log "Optiune invalida"
echo "Optiune invalida."
continue
;;
esac
;;
3)
debug_log "Introducere extensie fisier"
echo "Introdu extensia fisierului (fara punct)"
read ext
fisiere_gasite=$(find "$dir" -type f -name "*.$ext")
;;
4)
debug_log "Oprire cautare"
echo "Oprire cautare"
break
;;
*)
debug_log "Optiune invalida. Alege din nou"
echo "Optiune invalida. Alege din nou:"
continue
;;
esac
debug_log "Fisierele gasite sunt $fisiere_gasite"
echo "Fisiere gasite:"
echo "$fisiere_gasite"
if [[ -z "$fisiere_gasite" ]]; then
debug_log "Nu s-au gasit fisiere"
echo "Nu s-au gasit fisiere."
else
if [[ -n "$fisiere_gasite" ]]; then
debug_log "Doresti flirtrarea dupa alt criteriu?"
echo "Doresti filtrarea dupa alt criteriu? (y/n): "
read optiune
if [[ "$optiune" == "n" ]]; then
break
fi
fi
fi
done

}

##Meniu interactiv
while true; do
echo "*********************************************************"
echo "MENIU"
echo "*********************************************************"
echo "1) Gasirea fisierelor mai vechi de o data specificata de utilizator de la tastatura"
echo "2) Mutarea fisierelor local"
echo "3) Mutarea fisierelor in cloud"
echo "4) Stergerea fisierelor"
echo "5) Redenumirea fisierelor"
echo "6) Editarea continutului fisierului"
echo "7) Mutarea fisiere mai mari de 100 MB intr un alt director"
echo "8) Arhivare si comprimare a unui fisier sau director"
echo "9) Compararea continutului a doua entitati"
echo "10) Cautarea fisierelor dupa mai multe criterii"
echo "0) Iesire"
echo -n "Alege o optiune: "
read optiune
echo

case "$optiune" in 
1)
debug_log "Gasirea fisierelor mai vechi de o data specificata de utilizator de la tastatura:"
f_gasire_fisiere
;;
2)
debug_log "Mutarea fisierelor local:"
f_mutare_local
;;
3)
debug_log "Mutarea fisierelor in cloud:"
f_mutare_cloud
;;
4)
debug_log "Stergerea fisierelor:"
f_stergere
;;
5)
debug_log "Redenumirea fisierelor:"
f_redenumire
;;
6)
debug_log "Editarea continutului fisierului:"
f_editare
;;
7)
debug_log "Mutare fisiere mai mari de 100 MB intr un alt director:"
f_mutare_fisiere_mari
;;
8)
debug_log "Arhivarea si comprimarea fisierelor:"
f_arhivare_si_comprimare
;;
9)
debug_log "Compararea continutului a doua entitati:"
f_comparare_entitati
;;
10)
debug_log "Cautarea fisierelor dupa criterii"
cautare_fisiere
;;
0)
debug_log "Iesire din aplicatie"
break
;;
*)
echo "Optiune invalida!"
;;
esac
done
