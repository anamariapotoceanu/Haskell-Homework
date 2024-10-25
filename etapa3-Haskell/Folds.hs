{-# OPTIONS_GHC -Wno-missing-methods #-}
module Folds where

import Data.List hiding (union)
import Shallow (Point, Region, Transformation)
import qualified Shallow as S

{-
    Contructor de tip care surprinde regiunile elementare și modalitățile
    generice de construcție a regiunilor complexe (Complement etc.). Spre
    deosebire de etapa 2, în care constructorul de tip RegionAST nu era
    parametrizat, constructorul RegionShape este acum parametrizat cu un tip
    generic de informație, a, care înlocuiește referirile recursive la tipul
    RegionAST. De exemplu, (Complement RegionAST) din etapa 2 devine acum
    (Complement a). Cuvântul „shape” din numele tipului vizează formele generice
    (Complement, Union etc.) pe care le pot lua valorile acestui tip, fără
    a fixa tipul câmpurilor. Așa cum vom vedea în continuare, acest artificiu
    permite atât recuperarea tipului recursiv RegionAST, cât și implementarea
    unui mecanism generic de folding (reducere) al valorilor acestui tip.
-}
data RegionShape a
    = FromPoints [Point]
    | Rectangle Float Float
    | Circle Float
    | Complement a
    | Union a a
    | Intersection a a
    | Transform TransformationAST a
    deriving (Show, Eq)

{-
    Contructor de tip care surprinde transformările elementare și o variantă
    generică de construcție a transformărilor complexe (Combine). Explicațiile
    referitoare la RegionShape sunt valabile și aici.
-}
data TransformationShape a
    = Translation Float Float
    | Scaling Float
    | Combine [a]
    deriving (Show, Eq)

{-
    Tipul recursiv RegionAST din etapa 2 se poate recupera particularizând
    tipul a din definiția constructorului RegionShape la... RegionAST însuși.
    Cu alte cuvinte, RegionAST este un punct fix al constructorului de tip
    RegionShape, adică RegionAST = RegionShape RegionAST (egalul ar trebui citit
    mai degrabă ca „izomorf cu” în loc de „identic cu”, din perspectiva
    limbajului). Vă puteți convinge de relația de mai sus substituind textual
    aparițiile lui a din definiția lui RegionShape cu RegionAST; de exemplu,
    (Complement a) devine (Complement RegionAST).

    newtype este similar cu data, în sensul că definește un tip nou, dar poate
    fi folosit doar când precizăm un unic constructor de date (R de mai jos),
    care posedă un unic câmp (având mai jos tipul (RegionShape RegionAST)).
    Există și alte diferențe subtile pe care nu le vom detalia, dar îl puteți
    folosi în continuare ca pe un data obișnuit.
-}
newtype RegionAST
    = R (RegionShape RegionAST)
    deriving (Eq)

{-
    Similar se poate recupera și tipul TransformationAST din etapa 2.
-}
newtype TransformationAST
    = T (TransformationShape TransformationAST)
    deriving (Eq)

{-
    Funcțiile pe regiuni și transformări au implementări foarte similare celor
    din etapa 2, singura diferență constând în apariția constructorilor de date
    R și T de mai sus, pentru a reflecta noile definiții ale tipurilor RegionAST
    și TransformationAST în termenii constructorilor de tip RegionShape,
    respectiv TransformationShape.
-}
fromPoints :: [Point] -> RegionAST
fromPoints = R . FromPoints

rectangle :: Float -> Float -> RegionAST
rectangle width height = R $ Rectangle width height

circle :: Float -> RegionAST
circle = R . Circle

complement :: RegionAST -> RegionAST
complement = R . Complement

union :: RegionAST -> RegionAST -> RegionAST
union region1 region2 = R $ Union region1 region2

intersection :: RegionAST -> RegionAST -> RegionAST
intersection region1 region2 = R $ Intersection region1 region2

translation :: Float -> Float -> TransformationAST
translation tx ty = T $ Translation tx ty

scaling :: Float -> TransformationAST
scaling = T . Scaling

{-
    Smart constructor: dacă lista de transformări este singleton, înlocuiește
    lista cu unica transformare din listă; altfel, utilizează constructorul
    de date Combine.
-}
combineTransformations :: [TransformationAST] -> TransformationAST
combineTransformations [transformation] = transformation
combineTransformations transformations = T $ Combine transformations

{-
    Smart constructor: dacă se dorește aplicarea unei liste vide de transformări
    asupra unei regiuni, întoarce regiunea ca atare; altfel, utilizează
    constructorul de date Transform.
-}
applyTransformation :: TransformationAST -> RegionAST -> RegionAST
applyTransformation (T (Combine [])) region = region
applyTransformation transformation region = R $ Transform transformation region

{-
    *** TODO ***

    Instanțiați clasa Show cu tipul TransformationAST, pentru a reprezenta
    transformările sub formă de șir de caractere, astfel:

    * o translație cu parametrii tx și ty devine "+(tx,ty)"
    * o scalare cu factorul f devine "*<f>"
    * o transformare compusă este reprezentată ca lista Haskell
      a transformărilor constitutive.
    
    Hint: când faceți pattern matching conform noii definiții a tipului
    TransformationAST în termenii constructorului de tip TransformationShape,
    nu uitați constructorul de date T.

    Exemple:

    > combineTransformations [ translation 1 2
                             , scaling 3
                             , combineTransformations [ scaling 4
                                                      , translation 5 6
                                                      ]
                             ]
    [+(1.0,2.0),*<3.0>,[*<4.0>,+(5.0,6.0)]]
-}

{-
    Avem o instantiere a clasei Show pentru a transforma o valoare de tip
    TransformationAST într-un șir de caractere.
    Functia show va folosi pattern matching. Pattern matching-ul este folosit
    pentru a lucra cu diferite transformări in cazul acesta.
    show(tx, ty) transforma perechea de valori intr-un sir de caractere.
    Translatia devine "+(tx,ty)".
    Similar se procedeaza si pentru scalare. Translatia devine "*<f>".
    In cazul lui Combine, vom folosi map pentru a aplica functia show pe fiecare
    transformare. Intercalate are rolul de a insera "," intre doua elemente
    consecutive.
-}
instance Show TransformationAST where
    show (T (Translation tx ty)) = "+" ++ show (tx, ty)
    show (T (Scaling factor)) = "*" ++ "<" ++ show factor ++ ">"
    show (T (Combine transformations)) =
        "[" ++ intercalate "," (map show transformations) ++ "]"

{-
    *** TODO ***

    Instanțiați clasa Show cu tipul RegionAST, pentru a reprezenta regiunile
    sub formă de șir de caractere, astfel:

    * fiecare nod din AST apare pe propriul rând
    * un nod copil este indentat cu două spații față de părintele său
    * un nod frunză FromPoints, Rectangle sau Circle este afișat ca în etapa 2
    * un nod Transform este reprezentat prin transformarea aferentă
    * un nod Complement este reprezentat prin caracterul '~'
    * un nod Union este reprezentat prin caracterul '+'
    * un nod Intersection este reprezentat prin caracterul '*'.
    
    Hints:
    
    * Când faceți pattern matching conform noii definiții a tipului RegionAST
      în termenii constructorului de tip RegionShape, nu uitați constructorul
      de date R.
    * Definiți o funcție ajutătoare care ia ca parametru nivelul curent
      din arbore, pentru a ști câtă indentare să aplicați.
    * Funcția replicate permite construirea unei liste prin repetarea
      unui element de un anumit număr de ori.

    Constrângeri: evitați duplicarea codului.

    Exemple:

    > union (complement (fromPoints [(1, 1)]))
            (intersection (applyTransformation (translation 1 2) (circle 3))
                          (rectangle 4 5))
    +
      ~
        FromPoints [(1.0,1.0)]
      *
        +(1.0,2.0)
          Circle 3.0
        Rectangle 4.0 5.0
-}


{-
    Cum fiecare nivel de indentare va fi format din spatii, am definit
    indent pentru a determina numarul de spatii necesare. Va lua nivelul
    curent si determina cate spatii trebuie aplicate. 
    FromPoints, Rectangle si Circle sunt definite ca fiind noduri frunza,
    vom face identare folosind nivelul curent.
    Pentru Complement si Transform deoarece avem un singur copil, crestem
    nivelul de identare cu 1, pentru a fi identat cu doua spatii fata de
    nodul parinte.
    Pentru Union si Intersection, avem doua copii si fiecare trebuie
    identat cu doua spatii in plus fata de parinte. Pentru a face acest lucru
    adaugam la nivel 1.
    Am definit o functie auxiliara care ia ca paramentrul nivelul curent
    din arbore si determina cate spatii de identare sunt necesare.
-}

instance Show RegionAST where
    show region = showRegion 0 region
      where
        showRegion :: Int -> RegionAST -> String
        showRegion nivel (R regionShape) = case regionShape of
            FromPoints points ->
                indent nivel ++ "FromPoints" ++ " " ++ show points
            Rectangle width height ->
                indent nivel ++ "Rectangle" ++ " " ++ show width ++ " " ++ show height
            Circle radius ->
                indent nivel ++ "Circle" ++ " " ++ show radius
            Complement region ->
                indent nivel ++ "~" ++ "\n" ++ showRegion (nivel + 1) region
            Union region1 region2 ->
                indent nivel ++ "+" ++ "\n" ++ showRegion (nivel + 1) region1 ++ "\n" ++ showRegion (nivel + 1) region2
            Intersection region1 region2 ->
                indent nivel ++ "*" ++ "\n" ++ showRegion (nivel + 1) region1 ++ "\n" ++ showRegion (nivel + 1) region2
            Transform transformation region ->
                indent nivel ++ show transformation ++ "\n" ++ showRegion (nivel + 1) region

        indent :: Int -> String
        indent nivel = replicate (2 * nivel) ' '
{-
    *** TODO ***

    Instanțiați clasa Num și implementați doar funcțiile de mai jos, pentru
    a putea privi tipul RegionAST ca pe un tip numeric, astfel:

    * interpretarea unui întreg n este regiunea care include doar punctul (n, n)
    * negația (minus unar) unei regiuni corespunde complementului
    * suma a două regiuni corespunde reuniunii
    * produsul a două regiuni corespunde intersecției.

    Deși nu am definit până acum constructori de date sau funcții pentru
    reprezentarea diferenței a două regiuni (operatorul (-) de mai jos),
    ea poate fi implementată ca intersecție cu complementul scăzătorului.

    Constrângeri:
    
    * negate, (+) și (*) trebui definite point-free
    * (-) trebuie implementat exclusiv prin alți operatori aritmetici pe regiuni.

    Hint: folosiți direct funcțiile de construcție de mai sus (de exemplu,
    complement) în locul constructorilor de date (de exemplu, Complement) pentru
    a evita operarea directă cu constructorii de date R și T.

    Observație: în mod normal, întrucât nu implementăm chiar toate funcțiile
    din clasa Num, Haskell ar genera warning. Acest lucru este totuși împiedicat
    prin opțiunea -Wno-missing-methods de la începutul fișierului.

    Exemple:

    > fromInteger 1 :: RegionAST   
    FromPoints [(1.0,1.0)]

    > 1 :: RegionAST  -- aici se invocă implicit fromInteger pe 1
    FromPoints [(1.0,1.0)]

    > fromInteger (-1) :: RegionAST
    FromPoints [(-1.0,-1.0)]

    > -1 :: RegionAST  -- aici se invocă implicit fromInteger pe 1
    ~
      FromPoints [(1.0,1.0)]

    > circle 3 - rectangle 4 5        
    *
      Circle 3.0
      ~
        Rectangle 4.0 5.0

    > -1 + applyTransformation (translation 1 2) (circle 3) * rectangle 4 5
    +
      ~
        FromPoints [(1.0,1.0)]
      *
        +(1.0,2.0)
          Circle 3.0
        Rectangle 4.0 5.0
-}

{-
    RegionAST est instanta a clasei Num.
    Putem folosi operatii aritmetice similare cu numerele.
    
    * interpretarea unui întreg n cva fiind o regiune. Regiunea include doar punctul (n, n).
    * negatia va fi complementul regiunii.
    * suma a doua regiuni va fi reuniunea lor.
    * produsul a doua regiuni va fi intersecția lor.
 
-}
instance Num RegionAST where
    fromInteger n = fromPoints [(fromInteger n, fromInteger n)]
    
    negate = complement

    (+) = union

    (*) = intersection


  

    {-
        Diferența regiunilor trebuie implementată exclusiv prin alți operatori
        aritmetici pe regiuni, definiți în instanța curentă.
    -}
    region1 - region2 = region1 * complement region2

{-
    *** TODO ***

    Instanțiați clasa Functor cu constructorul TransformationShape. Funcția f,
    cu tipul (a -> b), pe care fmap o ia ca parametru, poate fi aplicată numai
    unde există un câmp de tipul a. Celelalte valori își păstrează forma
    originală.

    Exemple:

    > fmap (+ 1) $ Translation 1 2  -- am particularizat a la un tip numeric
    Translation 1.0 2.0

    > (+ 1) <$> Translation 1 2  -- (<$>) este sinonim pentru fmap
    Translation 1.0 2.0

    > fmap (+ 1) $ Scaling 3
    Scaling 3.0

    > fmap (+ 1) $ Combine [1, 2, 3]
    Combine [2,3,4]

    Observați că fmap aplicat pe un Translation sau un Scaling nu are efect,
    întrucât acestea nu conțin câmpuri de tipul a.

    În cazul în care vă nedumirește ultimul exemplu, rețineți că noul
    constructor de date Combine al constructorului de tip TransformationShape
    are un câmp de tipul [a], și nu de tipul [TransformationAST].
-}
{-
    Vom aplica o functie asupra elementelor din TransformationShape.
    Doar Combine contine elemente de tipul a.
-}
instance Functor TransformationShape where
    -- fmap :: (a -> b) -> TransformationShape a -> TransformationShape b
    fmap f transformation = case transformation of
        Translation tx ty -> Translation tx ty
        Scaling factor -> Scaling factor
        Combine transformations -> Combine (map f transformations)

{-
    *** TODO ***

    Instanțiați clasa Functor cu constructorul RegionShape. Funcția f,
    cu tipul (a -> b), pe care fmap o ia ca parametru, poate fi aplicată numai
    unde există un câmp de tipul a. Celelalte valori își păstrează forma
    originală.

    Exemple:

    > fmap (+ 1) $ Circle 1  -- am particularizat a la un tip numeric
    Circle 1.0

    > fmap (+ 1) $ Union 1 2
    Union 2 3

    Observați că fmap aplicat pe un Circle nu are efect, întrucât acesta
    nu conține câmpuri de tipul a.

    În cazul în care vă nedumirește ultimul exemplu, rețineți că noul
    constructor de date Union al constructorului de tip RegionShape are două
    câmpuri de tipul a, și nu de tipul RegionAST.
-}

{-
    Pentru a instantia clasa Functor pentru RegionShape, trebuie sa definim
    functia fmap.
    Functia fmap va aplica o functie asupra elementelor din RegionShape.
    data RegionShape a
    = FromPoints [Point]
    | Rectangle Float Float
    | Circle Float
    | Complement a
    | Union a a
    | Intersection a a
    | Transform TransformationAST a
    deriving (Show, Eq)
    Vom aplica functia doar asupra elementelor de tip a. Acestea apar
    la Union, Intersection si Complement si Transform. Restul vor ramane
    nemodificate.
-}
instance Functor RegionShape where
    -- fmap :: (a -> b) -> RegionShape a -> RegionShape b
    fmap f region = case region of
        FromPoints points -> FromPoints points
        Rectangle width height -> Rectangle width height
        Circle radius -> Circle radius
        Complement region -> Complement (f region)
        Union region1 region2 -> Union (f region1) (f region2)
        Intersection  region1 region2 -> Intersection (f region1) (f region2)
        Transform transformation region -> Transform transformation (f region)

{-
    Tipul (TransformationCombiner a) include funcții care pot combina câmpurile
    de tipul a din interiorul unei valori de tipul (TransformationShape a) la o
    singură valoare de tipul a.

    Tipul (RegionCombiner a) include funcții care pot combina câmpurile de tipul
    a din interiorul unei valori de tipul (RegionShape a) la o singură valoare
    de tipul a.

    În continuare, ne vom referi la aceste funcții prin „combiner-e”.
-}
type TransformationCombiner a = TransformationShape a -> a
type RegionCombiner a = RegionShape a -> a

{-
    *** TODO ***

    Implementați funcționalele foldTransformationAST și foldRegionAST, care au
    definiții aproape identice, pentru a putea reduce (fold) AST-uri de tipul
    TransformationAST, respectiv RegionAST, la o singură valoare de tipul a,
    pornind de la combiner-e cu tipurile (TransformationCombiner a), respectiv
    (RegionCombiner a).
    
    Pentru definirea unei funcționale fold...AST, se urmează doi pași:

    1. Se reduc mai întâi subarborii folosind recursiv funcționala fold...AST,
       pentru a înlocui subarborii de tipul ...AST cu acumulatori de tipul a.
    2. Se aplică combiner-ul pe rezultat, pentru a combina acumulatorii interni
       de tipul a într-o singură valoare de tipul a.
    
    Cele două funcționale vor avea câte o unică definiție (nu este necesar
    să faceți pattern matching pe forma parametrilor, e.g. translație,
    complement etc.), întrucât forma acestora este gesionată de combiner-ul
    primit ca parametru.

    Constrângere: folosiți fmap.

    Exemple:

    labelCombiner :: TransformationCombiner String
    labelCombiner (Translation _ _) = "t"
    labelCombiner (Scaling _) = "s"
    labelCombiner (Combine labels) = concat labels

    > foldTransformationAST labelCombiner $
        combineTransformations [ translation 1 2
                               , scaling 3
                               , combineTransformations [ scaling 4
                                                        , translation 5 6
                                                        ]
                               ]
    "tsst"

    Observați că, în ultima definiție a lui labelCombiner, pentru consructorul
    Combine, asumăm că acel câmp cu tipul [TransformationAST] a fost deja redus
    la (labels :: [String]), și singura preocupare este de a combina șirurile
    intermediare într-un nou șir.
-}

{-
    Vom reduce AST de tipul TransformationAST la o singura valoare de tipul a.
    Acest lucru il vom face dupa ce aplicam recursiv foldTransformationAST pe
    fiecare elemenet. Vom face acest lucru pentru a obtine elementele de tipul a.
    In final, se aplica combiner-ul pe rezultat final, pentru a obtine o singura
    valoare.
    Reducem un intreg arbore AST la o singura valoare.
    * transformation este de tipul TransformationShape a.
    Vom descompune TransformationAST in TransformationShape a.
-}
foldTransformationAST :: TransformationCombiner a -> TransformationAST -> a
foldTransformationAST f (T transformation) =   f (fmap (foldTransformationAST f) transformation)

foldRegionAST :: RegionCombiner a -> RegionAST -> a
foldRegionAST f (R region) = f (fmap (foldRegionAST f) region)

{-
    *** TODO ***

    Reimplementați funcția toTransformation din etapa 2, ca o reducere a unui
    TransformationAST. La fel ca în etapa 2, puteți invoca funcțiile din etapa 1
    prefixându-le cu „S.”.

    Hints:
    
    * Tipul (TransformationCombiner Transformation) se expandează la tipul
      (TransformationShape Transformation -> Transformation). Prin urmare,
      puteți asuma că, în cazul constructorului Combine, câmpul cu tipul
      [TransformationAST] a fost deja redus la [Transformation].
    * Implementarea ar trebui să fie aproape identică cu cea din etapa 2,
      singura diferență fiind înlăturarea interpretării explicite a subarborilor
      din etapa 2.
-}
toTransformation :: TransformationAST -> Transformation
toTransformation = foldTransformationAST combiner
  where
    combiner :: TransformationCombiner Transformation
    combiner transformation = case transformation of
        Translation tx ty -> S.translation tx ty
        Scaling factor -> S.scaling factor
        Combine transformations -> S.combineTransformations transformations

{-
    *** TODO ***

    Implementați funcția basicTransformationCount, ca o reducere a unui
    TransformationAST, care numără transformările elementare (translații
    și scalări) din cadrul unei alte transformări.

    Hint: tipul (TransformationCombiner Int) se expandează la tipul
    (TransformationShape Int -> Int). Prin urmare, puteți asuma că, în cazul
    constructorului Combine, câmpul cu tipul [TransformationAST] a fost deja
    redus la [Int].

    Exemple:

    > basicTransformationCount (translation 1 2)
    1

    > basicTransformationCount (scaling 3)
    1

    > basicTransformationCount $
        combineTransformations [ translation 1 2
                               , combineTransformations [ translation 3 4
                                                        , scaling 2
                                                        ]
                               , scaling 3
                               ]
    4
-}
basicTransformationCount :: TransformationAST -> Int
basicTransformationCount = foldTransformationAST combiner
  where
    combiner :: TransformationCombiner Int
    combiner transformation = case transformation of
        Translation tx ty -> 1
        Scaling factor -> 1
        Combine transformations -> sum transformations

{-
    *** TODO ***

    Implementați funcția basicEntityCount, ca o reducere a unui RegionAST, care
    numără regiunile (regiuni din puncte, dreptunghiuri și cercuri) și
    transformările elementare (translații și scalări) din cadrul unei alte
    regiuni. Cele două numere sunt întoarse într-o pereche.

    Hint: tipul (RegionCombiner (Int, Int)) se expandează la tipul
    (RegionShape (Int, Int) -> (Int, Int)). Prin urmare, puteți asuma că,
    în cazul constructorilor Transform, Union etc., câmpurile cu tipul RegionAST
    au fost deja reduse la (Int, Int).

    Constrângeri: evitați duplicarea codului.

    Cum ajută evaluarea leneșă dacă dorim să accesăm doar o componentă a perechii?
    
    Răspuns: Evaluarea lenesa ajuta sa evaluam doar componenta necesara dintr-o
    pereche. Fie ca vrem doar numarul de regiuni sau numarul de transformari. 

    Exemple:

    > basicEntityCount $
        union (applyTransformation
                  (combineTransformations
                      [ translation 1 2
                      , combineTransformations [ translation 3 4
                                               , scaling 2
                                               ]  
                      , scaling 3
                      ])
                  (complement
                      (applyTransformation
                          (scaling 4)
                          (applyTransformation (scaling 2) (circle 5)))))
              (applyTransformation (translation 4 6) (rectangle 6 7))
    (2, 7)

    Avem 2 regiuni elementare și 7 transformări elementare.
-}


{-
    Pentru FromPoints, Rectangle, Circle aveam doar o regiune elementara si
    0 transformari.
    Pentru Complement vom returna direct valorile.
    Atat pentru Union, cat si pentru Intersection, avem doua regiuni.
    Se aduna atat numarul de transformari elementare, cat si numarul de regiuni.
    Pentru Transform, region ramane neschimbat. Numarul de transformari elementare se aduna
    cu numarul de transformari elementare din transformation.
-}
basicEntityCount :: RegionAST -> (Int, Int)
basicEntityCount = foldRegionAST combiner
  where
    combiner :: RegionCombiner (Int, Int)
    combiner region = case region of
        FromPoints _ -> (1, 0)
        Rectangle _ _-> (1, 0)
        Circle _ -> (1, 0)
        Complement (region1, transf1) -> (region1, transf1)
        Union (region1, transf1) (region2, transf2)
                    -> (region1 + region2, transf1 + transf2)
        Intersection (region1, transf1) (region2, transf2)
                    -> (region1 + region2, transf1 + transf2)
        Transform transformation (region, transf) 
                    -> (region, transf + basicTransformationCount transformation)

{-
    *** TODO ***

    Reimplementați funcția show pe regiuni ca o reducere a unui RegionAST,
    și apoi modificați flag-ul de mai jos la True.

    În funcție de cum ați implementat-o inițial, rescrierea se poate realiza
    direct sau poate necesita niște modificări prealabile. De exemplu, dacă
    ați urmat hint-ul din comentariile funcției show, legat de definirea unei
    funcții ajutătoare care să ia și nivelul curent ca parametru, ați scris
    probabil definiții de forma

    helper level region = ... helper (level + 1) subRegion ...,

    unde helper întoarce un șir. Dacă parametrii sunt luați în ordinea de mai
    sus, operația NU este compozițională, întrucât rezultatul calculat de
    funcția (helper level) aplicată pe o regiune depinde nu de rezultatul
    aplicării aceleiași funcții (helper level) pe subregiuni, ci al altei
    funcții, (helper (level + 1)). Prin urmare, definiția de mai sus nu poate fi
    rescrisă direct ca o reducere, prin intermediul funcționalei foldRegionAST.
    Totuși, se poate recurge la următorul artificiu, care presupune inversarea
    parametrilor:

    helper' region level = ... helper' subRegion (level + 1) ...

    Aceasta este o operație compozițională, întrucât rezultatul funcției helper'
    aplicată pe o regiune depinde numai de rezultatul aplicării aceleiași
    funcții helper' pe subregiuni. Diferența este că helper' aplicată pe o
    regiune nu mai întoarce direct un șir, ci o funcție (\level -> string), care
    știe să producă reprezentarea sub formă de șir a unui arbore după ce
    primește nivelul curent ca parametru. Fiind o operație compozițională,
    helper' poate fi rescrisă ca o reducere.
-}
showFoldFlag :: Bool
showFoldFlag = False