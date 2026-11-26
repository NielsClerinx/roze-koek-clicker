# Genereert data/buildings.json en data/upgrades.json (bron van waarheid voor balans).
import json, os
ROOT = os.path.join(os.path.dirname(__file__), "..", "data")
B = [
 ("kleine_bakker","Kleine bakker",15,0.1,"#F7A8C4","Een mannetje met een te grote koksmuts. Bakt traag, maar met liefde."),
 ("bakkerij","Bakkerij",110,1,"#F48FB1","Een hoekbakkerij met roze luifel. Ruikt naar fondant en ambitie."),
 ("oven","Professionele oven",1200,8,"#E57399","Glimmend, heet en altijd vol. Zelfs de deur is roze."),
 ("fondantmijn","Fondantmijn",13000,45,"#D9668F","Diep in de berg ligt roze fondant. Mijnwerkers zingen erbij."),
 ("industriele_bakkerij","Industriële bakkerij",140000,250,"#C9A0DC","Rokende schoorstenen, ploegendiensten en een koffieautomaat."),
 ("fabriek","Roze koek-fabriek",1.5e6,1400,"#B39DDB","Een fabriek in de vorm van een gigantische roze koek. Uiteraard."),
 ("productielijn","Geautomatiseerde productielijn",1.8e7,8000,"#9FA8DA","Grijparmen, glazuurspuiten en nul pauzes."),
 ("robotbakkers","Robotbakkers",2.4e8,45000,"#90CAF9","Robots met schortjes. Hun glimlach is iets té breed."),
 ("bakkerijketen","Internationale bakkerijketen",3.2e9,260000,"#80DEEA","Van Tilburg tot Tokio: overal roze koeken."),
 ("maffia","Roze koek-maffia",4.5e10,1.6e6,"#80CBC4","Een aanbod dat niemand kan weigeren. Krijtstreep en fondant."),
 ("laboratorium","Ondergronds laboratorium",6.5e11,1e7,"#A5D6A7","Bubbelende reageerbuizen. Niemand weet wat er in de kelder gebeurt."),
 ("ruimtefabriek","Ruimtefabriek",9.5e12,6.4e7,"#C5E1A5","Laat roze koeken als meteoren op de aarde regenen."),
 ("tijdmachine","Tijdmachine",1.4e14,4.2e8,"#FFE082","Haalt koeken op die je gisteren al gebakken hebt."),
 ("multiversum","Multiversumfabriek",2.1e15,2.8e9,"#FFCC80","Ergens is er een universum waar alles roze koek is. Dit is de fabriek daar."),
 ("goddelijk","Goddelijke roze koekproductie",3.2e16,2e10,"#FFAB91","De Opperkoek is ontwaakt. Hij bakt zichzelf."),
]
T12 = {
 "kleine_bakker":("Grotere koksmuts","Oma's geheime deegroller"),
 "bakkerij":("Neonbord \"Vers!\"","Wachtrij tot op straat"),
 "oven":("Turbo-hete lucht","Zelfreinigend glazuur"),
 "fondantmijn":("Roze dynamiet","Zuurstokhelmen"),
 "industriele_bakkerij":("Ploegendienst","Vakbondskoekjes"),
 "fabriek":("Roze lopende banden","Dubbele glazuurlaag"),
 "productielijn":("Firmware 2.0","AI-glazuurspuit"),
 "robotbakkers":("Robotschortjes","Robots met gevoel"),
 "bakkerijketen":("Franchise in Tilburg","Filiaal op de Noordpool"),
 "maffia":("Een aanbod dat je niet kunt weigeren","Witwassen in de vaatwasser"),
 "laboratorium":("Gekloonde koeken","Fondant-isotopen"),
 "ruimtefabriek":("Nul-zwaartekracht-glazuur","Koekenmeteoren"),
 "tijdmachine":("Gisteren al gebakken","Paradoxale ovens"),
 "multiversum":("Parallelle bakkers","Universum waar koeken gratis zijn"),
 "goddelijk":("Heilig glazuur","De Opperkoek ontwaakt"),
}
SUFFIX = ["Deluxe","Ultra","Absurd","Kosmisch"]
THRESH = [1,5,25,50,100,150]
COSTM = [10,50,500,5e4,5e6,5e8]
buildings = [dict(id=i,name=n,base_cost=c,base_kps=k,color=col,description=d) for i,n,c,k,col,d in B]
ups = []
def up(id,name,desc,cost,cond,effects,secret=False):
    ups.append(dict(id=id,name=name,description=desc,cost=cost,condition=cond,effects=effects,secret=secret))
up("click_1","Dubbele vingers","Twee vingers tikken beter dan één. Klikkracht x2.",100,{"type":"building_count","building":"kleine_bakker","count":1},[{"type":"click_mult","value":2}])
up("click_2","Kneedhanden","Sterke handen van het vele kneden. Klikkracht x2.",500,{"type":"building_count","building":"bakkerij","count":1},[{"type":"click_mult","value":2}])
up("click_3","Glazuurduim","Je duim is permanent roze. Klikkracht x2.",10000,{"type":"building_count","building":"bakkerij","count":10},[{"type":"click_mult","value":2}])
up("click_4","Fondantvuist","Elke tik levert extra 1% van je koeken per seconde op.",5e5,{"type":"total_baked","value":1e6},[{"type":"click_kps_pct","value":0.01}])
up("click_5","Roze reflexen","Kritieke kans +4%.",5e7,{"type":"total_baked","value":1e8},[{"type":"crit_chance_add","value":0.04}])
up("click_6","Tikmonster","+2% van KPS per tik en kritieke klikken x15 in plaats van x10.",5e9,{"type":"total_baked","value":1e10},[{"type":"click_kps_pct","value":0.02},{"type":"crit_mult_set","value":15}])
for (bid,bname,bc,bk,_,_) in B:
    for t in range(6):
        name = T12[bid][t] if t < 2 else f"{bname} {SUFFIX[t-2]}"
        up(f"{bid}_t{t+1}",name,f"{bname}: productie x2.",bc*COSTM[t],{"type":"building_count","building":bid,"count":THRESH[t]},[{"type":"building_mult","target":bid,"value":2}])
up("global_1","Roze bril","Alles ziet er roziger uit. Alle productie +10%.",1e6,{"type":"kps","value":1000},[{"type":"global_mult","value":1.10}])
up("global_2","Bakkerslied","Iedereen zingt mee. Alle productie +15%.",1e9,{"type":"kps","value":50000},[{"type":"global_mult","value":1.15}])
up("global_3","Roze koek-dag","Officiële feestdag. Alle productie +20%.",1e12,{"type":"kps","value":1e7},[{"type":"global_mult","value":1.20}])
up("global_4","Wereldwijde roze hype","Iedereen wil er een. Alle productie +25%.",1e15,{"type":"kps","value":1e9},[{"type":"global_mult","value":1.25}])
up("offline_1","Thermosfles koffie","Je bakkers werken harder als je weg bent. Offline efficiëntie +25%.",5e4,{"type":"total_baked","value":1e4},[{"type":"offline_eff_add","value":0.25}])
up("offline_2","Grote voorraadkast","Offline limiet +3 uur.",5e6,{"type":"total_baked","value":1e6},[{"type":"offline_cap_add","value":10800}])
up("golden_1","Glinsterende ogen","Gouden roze koeken verschijnen 20% vaker.",5e5,{"type":"golden_clicked","value":3},[{"type":"golden_freq_mult","value":1.25}])
up("secret_ikbendekoek","Ik ben de koek","Geheim gevonden! Klikkracht x3.",0,{"type":"secret"},[{"type":"click_mult","value":3}],True)
json.dump(buildings,open(os.path.join(ROOT,"buildings.json"),"w",encoding="utf-8"),ensure_ascii=False,indent=1)
json.dump(ups,open(os.path.join(ROOT,"upgrades.json"),"w",encoding="utf-8"),ensure_ascii=False,indent=1)
print(len(buildings),"buildings",len(ups),"upgrades")
