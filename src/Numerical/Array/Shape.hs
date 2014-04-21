{-# LANGUAGE DataKinds, GADTs, TypeFamilies #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE ExplicitForAll  #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE UnboxedTuples #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverlappingInstances #-}

module Numerical.Array.Shape(Shape(..)
    ,foldl
    ,foldr
    ,foldl'
    ,scanr
    ,scanl
    ,scanl1
    ,scanr1
    ,scanr1Zip
    ,scanl1Zip 
    ,map
    ,map2
    ,reverseShape
    ,At(..)
    ,Nat(..)
    ,shapeSize
    ,SNat(..)
    ,weaklyDominates
    ,strictlyDominates
    ,cons
    ,snoc
    ,unsnoc
    ,uncons 

    ,takeSuffix
    ,takePrefix) 
    where

import GHC.Magic 
import Data.Data 
import Data.Typeable()


import qualified Data.Monoid  as M 
import qualified Data.Functor as Fun 
import qualified  Data.Foldable as F
import qualified Control.Applicative as A 
import qualified Data.Traversable as T 

import Numerical.Nat 

import Prelude hiding  (map,foldl,foldr,init,scanl,scanr,scanl1,scanr1)



{-
Shape may get renamed to Index in the near future! 

-}

infixr 3 :*
    
 {-
the concern basically boils down to "will it specialize / inline well"

 -}

newtype At a = At  a
     deriving (Eq, Ord, Read, Show, Typeable, Functor)


data Shape (rank :: Nat) a where 
    Nil  :: Shape Z a
    (:*) ::  !(a) -> !(Shape r a ) -> Shape  (S r) a
        --deriving  (Show)

#if defined(__GLASGOW_HASKELL_) && __GLASGOW_HASKELL__ >= 707
deriving instance Typeable Shape 
#endif


instance  Eq (Shape Z a) where
    (==) _ _ = True 
instance (Eq a,Eq (Shape s a))=> Eq (Shape (S s) a )  where 
    (==)  (a:* as) (b:* bs) =  (a == b) && (as == bs )   

instance  Show (Shape Z a) where 
    show _ = "Nil"

instance (Show a, Show (Shape s a))=> Show (Shape (S s) a) where
    show (a:* as) = show a  ++ " :* " ++ show as 

-- at some point also try data model that
-- has layout be dynamicly reified, but for now
-- keep it phantom typed for sanity / forcing static dispatch.
-- NB: may need to make it more general at some future point
--data Strided r a lay = Strided {   getStrides :: Shape r a   }

-- may want to typeclassify this?
shapeSize :: Shape n a -> SNat n 
shapeSize Nil = SZero
shapeSize (a:* as) = SSucc (shapeSize as)

{- when you lift a toral order onto vectors, you get
interesting partial order -}
{-# SPECIALIZE weaklyDominates :: Shape n Int -> Shape n Int -> Bool #-}
{-# SPECIALIZE weaklyDominates :: Shape n Integer -> Shape n Integer -> Bool #-}
{-# SPECIALIZE weaklyDominates :: Shape n Double -> Shape n Double -> Bool #-}
{-# SPECIALIZE weaklyDominates :: Shape n Float -> Shape n Float -> Bool #-}
{-# SPECIALIZE weaklyDominates :: Shape n Rational -> Shape n Rational -> Bool #-}

{-# SPECIALIZE strictlyDominates :: Shape n Int -> Shape n Int -> Bool #-}
{-# SPECIALIZE strictlyDominates :: Shape n Integer -> Shape n Integer -> Bool #-}
{-# SPECIALIZE strictlyDominates :: Shape n Double -> Shape n Double -> Bool #-}
{-# SPECIALIZE strictlyDominates :: Shape n Float -> Shape n Float -> Bool #-}
{-# SPECIALIZE strictlyDominates :: Shape n Rational -> Shape n Rational -> Bool #-}
weaklyDominates, strictlyDominates :: Ord a => Shape n a -> Shape n a -> Bool 
weaklyDominates = \major minor -> foldl (&&) True $! map2 (>=)  major minor
strictlyDominates  = \major minor -> foldl (&&) True $! map2 (>)  major minor

{-# INLINE reverseShape #-}
reverseShape :: Shape n a -> Shape n a 
reverseShape Nil = Nil
reverseShape r@(a :* Nil)= r
reverseShape (a:* b :* Nil) = b:* a :* Nil
reverseShape (a:* b :* c:* Nil )=  c :* b :* a :* Nil
reverseShape (a:* b :* c :* d :* Nil)= d :* c :* b :* a :* Nil 
reverseShape list = go SZero Nil list
  where
    go :: SNat n1 -> Shape n1  a-> Shape n2 a -> Shape (n1 + n2) a
    go snat acc Nil = gcastWith (plus_id_r snat) acc
    go snat acc (h :* (t :: Shape n3 a)) =
      gcastWith (plus_succ_r snat (Proxy :: Proxy n3))
              (go (SSucc snat) (h :* acc) t)

--reverseShape :: Shape n a -> Shape n a 
--reverseShape Nil = Nil 
--reverseShape s@(a :* Nil ) = s 
--reverseShape (a:* b :* Nil) = (b:* a :* Nil )
--reverseShape (a:* b:* c :* Nil ) = (c :* b :* a :* Nil)
--reverseShape s = go SZero Nil s
--  where
--    go :: SNat n1 -> Shape n1  a-> Shape n2 a-> Shape (n1 + n2) a



--deriving instance Eq a => Eq (Shape Z a)

--instance   (Eq a,F.Foldable (Shape n), A.Applicative (Shape n)) => Eq (Shape n a) where
--    (==) = \ a  b -> F.foldr (&&) True $ map2 (==) a b 
--    (/=) = \ a  b -> F.foldr (||) False $ map2 (/=) a b 


--instance (Show a, F.Foldable (Shape n ) ) => 

--instance   Eq a => Eq (Shape n a) where
--    (==) = \ a  b -> F.foldr (&&) True $  A.pure ((==) :: a ->a -> Bool) A.<*> a A.<*> b
--    (/=) = \ a  b -> F.foldr (||) False $ A.pure (/= :: a ->a -> Bool) A.<*> a A.<*> b

    -- #if defined( __GLASGOW_HASKELL__ ) &&  ( __GLASGOW_HASKELL__  >= 707)
    --deriving instance Typeable (Shape rank a)
    -- #endif    

-- higher rank insances welcome :) 


--instance Fun.Functor (Shape r) where
--    fmap = mapShape 
--    {-#INLINE fmap #-}

instance Fun.Functor (Shape Z) where
    fmap  = \ _ Nil -> Nil 
    {-# INLINE  fmap #-}

instance  (Fun.Functor (Shape r)) => Fun.Functor (Shape (S r)) where
    fmap  = \ f (a :* rest) -> f a :* ( Fun.fmap f rest )
    {-# INLINE  fmap  #-}
instance  A.Applicative (Shape Z) where 
    pure = \ _ -> Nil
    {-# INLINE  pure  #-}
    (<*>) = \ _  _ -> Nil 
    {-# INLINE  (<*>) #-}
instance  A.Applicative (Shape r)=> A.Applicative (Shape (S r)) where     
    pure = \ a -> a :* (A.pure a)
    {-# INLINE pure #-}
    (<*>) = \ (f:* fs) (a :* as) ->  f a :* (inline (A.<*>)) fs as 
    {-# INLINE  (<*>) #-}



instance    F.Foldable (Shape  (S Z)) where
    foldl' = \ f !init (a:*Nil)->  f init a  
    foldr'  = \ f !init (a:*Nil)->  f a init  
    foldl  = \ f init (a:*Nil)->  f init a 
    foldr  = \ f init (a:*Nil)->  f a init  
    {-# INLINE foldMap  #-}
    {-#  INLINE foldl #-}
    {-#  INLINE foldr  #-}
    {-# INLINE foldl' #-}
    {-#  INLINE foldr'  #-}
    foldr1 = \ f (a:* Nil) -> a 
    foldl1 =  \ f (a:* Nil) -> a 
    {-#  INLINE foldl1 #-}
    {-#  INLINE foldr1 #-}
instance  F.Foldable (Shape r)=> F.Foldable (Shape (S r)) where    
    foldl' = \ f  init (a:* as) ->  
    foldr' = \f !init (a :* as ) -> f a $!  F.foldr f init as               
    foldl  = f  init (a:* as) ->
    foldr  =  f  init (a:* as) ->  
    {-# INLINE foldMap  #-}
    {-#  INLINE foldl #-}
    {-#  INLINE foldr  #-}
    {-# INLINE foldl' #-}
    {-#  INLINE foldr'  #-}



indexedPure :: A.Applicative (Shape n)=> SNat n -> a -> Shape n a 
indexedPure _ = \val -> A.pure val 
{-# INLINE indexedPure #-}
    
{-# INLINE foldlPShape   #-}
foldlPShape=foldl'
   

foldrShape=foldr
{-# INLINE  foldrShape #-}

foldlShape=foldl
{-# INLINE foldlShape #-}

mapShape = map 
{-# INLINE mapShape#-}



{-
TODO: abstract out all the different unrolled cases i have


-}



  
{-# INLINE map2 #-}    
map2 :: forall a b c r . (A.Applicative (Shape r))=>   (a->b ->c) -> (Shape r a) -> (Shape r b) -> (Shape r c )  
map2  = \ f shpa shpb -> f A.<$> shpa  A.<*> shpb 


{-# INLINE map #-}
map:: forall a b r . (A.Applicative (Shape r))=> (a->b) -> (Shape r a )->( Shape r b)        
map  =  \ f shp -> f A.<$> shp 



{-# INLINE  foldr #-}
foldr :: forall a b r . (A.Applicative (Shape r))=>  (a->b-> b) -> b -> Shape r a -> b 
foldr f = let
            go :: b -> Shape h a -> b 
            go start Nil = start 
            go start (a:* as) = f a $ go start as 
        in  \init theShape -> 
                case theShape of 
                    Nil -> init 
                    (a:* Nil ) -> f  a init
                    (a :* b :* Nil) ->  f a $ f b init 
                    (a :* b :* c :* Nil) -> f a $ f b  (f c init )
                    _ -> go init theShape





--yes i'm making foldl strict :) 
{-# INLINE  foldl #-}
foldl :: forall a b r. (b-> a -> b) -> b -> Shape r a -> b 
foldl f = let 
            go:: b  -> Shape h a -> b 
            go !init Nil = init
            go !init (a:* as) = go (f init  a) as
            in  \init theShape -> 
                case theShape of 
                    Nil -> init 
                    (a:* Nil ) -> f init a 
                    (a :* b :* Nil) -> f init a `f` b 
                    (a :* b :* c :* Nil) -> f init a `f` b `f` c
                    _ -> go init theShape
                 
{-# INLINE foldl' #-}                     
foldl' :: forall a b r. (b-> a -> b) -> b -> Shape r a -> b 
foldl' f =let 
            go:: b  -> Shape h a -> b 
            go !init Nil = init
            go !init (a:* as) = go (f init $! a) as
            in  \init theShape -> 
                case theShape of 
                    Nil -> init 
                    (a:* Nil ) -> f init a 
                    (a :* b :* Nil) -> f init a `f` b 
                    (a :* b :* c :* Nil) -> f init a `f` b `f` c
                    _ -> go init theShape


{-# INLINE scanl  #-}
scanl :: forall a b r . (b->a -> b) -> b -> Shape r a -> Shape (S r) b
scanl f  = let  
        go ::b -> Shape h a -> Shape (S h) b
        go !val Nil =  val :* Nil
        go !val (a:* as)=  val :* go res as
                    where !res = f val a 
        in \ init shp -> 
            case shp of 
                Nil -> init :* Nil  
                (a:* Nil) -> init  :* (f  init a ) :* Nil
                (a:* b :* Nil) -> init :* (f   init a )  :* ((f init  a  ) `f`  b ) :* Nil 
                (a :* b :* c :* Nil) ->init  :*  (f init a  ):* ((f init a ) `f` b) :* (((f init a ) `f` b) `f` c) :* Nil 
                _  ->  go init shp  

{-# INLINE scanl1  #-}
scanl1 :: forall a b r . (b->a -> b) -> b -> Shape r a -> Shape  r b
scanl1 f  = let  
        go ::b -> Shape h a -> Shape h b
        go val Nil =   Nil
        go val (a:* as)=  val :* go res as
            where res = f val a 
        in \ init shp -> 
            case shp of 
                Nil ->  Nil  
                (a:* Nil) ->   (f  init a ) :* Nil
                (a:* b :* Nil) ->  (f   init a )  :* ((f init  a  ) `f`  b ) :* Nil 
                (a :* b :* c :* Nil) -> (f init a  ):* ((f init a ) `f` b) :* (((f init a ) `f` b) `f` c) :* Nil 
                _  ->  go init shp  


{-# INLINE scanr1  #-}
scanr1 :: forall a b r . (a -> b -> b ) -> b -> Shape r a -> Shape  r b 
scanr1 f  = let 
        --(accum,!finalShape)= go f init shs
        go   ::  b -> Shape h a -> (b  ,Shape h b )
        go  init Nil = (init, Nil)
        go  init (a:* as) = (res, res :*  suffix)
            where 
                !(!accum,!suffix)= go  init as 
                !res =  f a accum
        in \ init shs -> 
            case shs of 
                Nil ->   Nil 
                (a:* Nil) ->  f a init:*   Nil
                (a:* b :* Nil) -> f a (f b init) :* (f b init ) :*   Nil 
                (a :* b :* c :* Nil) -> (f a $  f b $ f c init):* f b (f c init) :* (f c init )  :* Nil 
                _ -> snd   $! go init shs 
--should try out unboxed tuples once benchmarking starts


{-# INLINE scanr  #-}
scanr :: forall a b r . (a -> b -> b ) -> b -> Shape r a -> Shape (S r) b 
scanr f  = let 
        --(accum,!finalShape)= go f init shs
        go   ::  b -> Shape h a -> (b  ,Shape (S h) b )
        go  init Nil = (init,init  :*Nil)
        go  init (a:* as) = (res, res :*  suffix)
            where 
                !(!accum,!suffix)= go  init as 
                !res =  f a accum
        in \ init shs -> 
            case shs of 
                Nil -> init :* Nil 
                (a:* Nil) ->  f a init:* init  :* Nil
                (a:* b :* Nil) -> f a (f b init) :* (f b init ) :* init  :* Nil 
                (a :* b :* c :* Nil) -> (f a $  f b $ f c init):* f b (f c init) :* (f c init ) :* init :* Nil 
                _ -> snd   $! go init shs 
--should try out unboxed tuples once benchmarking starts

{-for now lets not unroll these two-}
{-# INLINE  scanr1Zip #-}
scanr1Zip  ::   forall a b c r . (a -> b -> c-> c ) -> c -> Shape r a ->Shape r b ->  Shape  r c
scanr1Zip f =
    let   
        go   ::  c -> Shape h a -> Shape h b -> (c  ,Shape  h c )
        go !init Nil Nil = (init ,Nil)         
        go  !init (a:* as) (b:* bs) = (res, res :*  suffix)
            where 
                !(!accum,!suffix)= go  init as bs 
                !res =  f a b accum
        in \ init as bs -> snd $! go init as bs  

{-# INLINE  scanl1Zip #-}
scanl1Zip  ::   forall a b c r . (c->a -> b -> c ) -> c -> Shape r a ->Shape r b ->  Shape  r c
scanl1Zip f =
    let   
        go   ::  c -> Shape h a -> Shape h b -> Shape  h c 
        go !init Nil Nil = Nil         
        go  !init (a:* as) (b:* bs) = res :*  go res as bs 
            where                  
                !res =  f init  a b 
        in \ init as bs ->  go init as bs  

{-# INLINE cons  #-}
cons :: a -> Shape n a -> Shape (S n) a 
cons = \ a as -> a :* as 

{-# INLINE snoc #-}
snoc ::  Shape n a -> a -> Shape (S n) a
snoc = let 
            go ::  Shape r a -> a -> Shape (S r) a
            go Nil val = val :* Nil 
            go (a:*as) val = a :* (go  as val )
            in 
                \ shp val -> 
                    case shp of 
                        Nil -> val :* Nil 
                        (a:* Nil ) -> a :* val :* Nil 
                        (a:* b :* Nil ) -> a:* b :* val :* Nil
                        (a:* b :* c:* Nil) -> a :* b :* c :* val :* Nil 
                        (a:* b :* c:* d :*  Nil) -> a :* b :* c  :* d  :* val :* Nil 
                        _ -> go shp val 


uncons :: Shape (S n)  a -> (a,Shape n a )
uncons = \(a:* as) -> (a , as )

unsnoc :: Shape (S n) a -> (Shape n a, a)
unsnoc = let 
        go :: Shape (S n) a -> (Shape n a, a  )
        go (a:* Nil) = (Nil,a) 
        go (a:* bs@(_ :* _)) = (a:*  (fst res), snd res ) 
            where res = go bs 
        in 
            go 




{-#INLINE takeSuffix#-}
takeSuffix :: Shape (S n) a -> Shape n a 
takeSuffix = \ (a:* as) -> as 

-- a sort of unsnoc
{-# INLINE takePrefix #-}
takePrefix :: Shape (S n) a -> Shape n a 
takePrefix = 
    let 
        go :: Shape (S n) a -> Shape n a 
        go (a:* Nil) = Nil 
        go (a:* bs@(_ :* _)) = a:*  go bs 
        in 
            \shp ->
                case shp of 
                    (a:* Nil) -> Nil
                    (a:* b :* Nil) -> (a:* Nil)
                    (a:* b :* c :* Nil)  -> (a:* b :* Nil )
                    (a:* b :* c :* d :* Nil ) -> (a:* b :* c :* Nil )
                    _ -> go shp 


{-
should benchmark the direct and CPS versions

-}

-- NB: haven't unrolled this yet
scanrCPS :: (a->b ->b) -> b -> Shape r a -> Shape r b 
scanrCPS  f init shs = go f  init shs (\accum final -> final)
    where
        go :: (a->b->b) -> b -> Shape h a -> (b-> Shape h  b -> c)->c
        go f init Nil cont = cont init Nil 
        go f init (a:* as) cont = 
            go f init as 
                (\ accum suffShape -> 
                    let moreAccum = f a accum in 
                        cont moreAccum (moreAccum:*suffShape) )








