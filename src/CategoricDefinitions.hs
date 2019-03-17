module CategoricDefinitions where

import Prelude hiding (id, (.))
import qualified Prelude as P
import GHC.Exts (Constraint)
import Data.Kind (Type)
import Data.NumInstances.Tuple

import Numeric.LinearAlgebra.Array
import Numeric.LinearAlgebra.Array.Util

-- Standard haskell way to define a category
class Category (k :: Type -> Type -> Type) where
    type Allowed k a :: Constraint
    type Allowed k a = ()

    id  :: Allowed k a => a `k` a
    (.) :: Allowed3 k a b c => b `k` c -> a `k` b -> a `k` c

-- By monoidal here we mean symmetric monoidal category
class Category k => Monoidal (k :: Type -> Type -> Type) where
    -- unit object in haskell is ()
    x :: Allowed6 k a b c d (a, b) (c, d)
      => (a `k` c) -> (b `k` d) -> ((a, b) `k` (c, d))
    assocL :: Allowed7 k a b c (a, b) ((a, b), c) (b, c) (a, (b, c))
           => ((a, b), c) `k` (a, (b, c))
    assocR :: Allowed7 k a b c (a, b) ((a, b), c) (b, c) (a, (b, c))
           => (a, (b, c)) `k` ((a, b), c)
    swap :: Allowed4 k a b (a, b) (b, a)
         => (a, b) `k` (b, a)

class Monoidal k => Cartesian k where
    type AllowedCar k a :: Constraint
    type AllowedCar k a = ()

    exl :: AllowedCar k b => (a, b) `k` a
    exr :: AllowedCar k a => (a, b) `k` b
    dup :: AllowedCar k a => a `k` (a, a)
    counit :: AllowedCar k a => a `k` ()

class Category k => Cocartesian k where
    type AllowedCoCar k a :: Constraint
    type AllowedCoCar k a = Allowed k a

    inl :: AllowedCoCar k b => a `k` (a, b)
    inr :: AllowedCoCar k a => b `k` (a, b)
    jam :: AllowedCoCar k a => (a, a) `k` a
    unit :: AllowedCoCar k a => () `k` a

{-
This is a hacky way of modelling a weak 2-category which is needed for Para.
Notice the tick' after class name
(.*) corresponds to id
(.-) corresponds to . (sequential comp)
(.|) corresponds to `x` (parallel comp)
-}

class Category' (k :: Type -> Type -> Type -> Type) where
    type Allowed' k a :: Constraint
    type Allowed' k a = ()

    (.*) :: (Allowed' k a) => k () a a
    (.-) :: (Allowed' k p, Allowed' k q,
             Allowed' k a, Allowed' k b, Allowed' k c)
          => k q b c -> k p a b -> k (p, q) a c

class Category' k => Monoidal' (k :: Type -> Type -> Type -> Type) where
    (.|) :: (Allowed' k a,
             Allowed' k b,
             Allowed' k c,
             Allowed' k d,
             Allowed' k p,
             Allowed' k q)
      => k p a c -> k q b d -> k (p, q) (a, b) (c, d)

{-
Swap map for monoidal product of parametrized functions, basically bracket bookkeeping.
Read from top to bottom
(a b) (c d)
a (b, (c, d))
a ((b, c), d)
a ((c, b), d)
a (c, (b, d))
(a c) (b d)
-}
swapParam :: (Monoidal k, _) => ((a, b), (c, d)) `k` ((a, c), (b, d))
swapParam = assocR . (id `x` assocL) . (id `x` (swap `x` id)) . (id `x` assocR) . assocL


--------------------------------------

class Additive a where
    zero :: a
    (^+) :: a -> a -> a

class NumCat (k :: Type -> Type -> Type) a where
    negateC :: a `k` a
    addC :: (a, a) `k` a
    mulC :: (a, a) `k` a
    increaseC :: a -> a `k` a -- curried add, add a single number

class FloatCat (k :: Type -> Type -> Type) a where
    expC :: a `k` a

class FractCat (k :: Type -> Type -> Type) a where
    recipC :: a `k` a

class Scalable (k :: Type -> Type -> Type) a where
    scale :: a -> (a `k` a)

type Tensor = NArray None Double

-------------------------------------
-- Instances
-------------------------------------

instance Category (->) where
    id    = \a -> a
    g . f = \a -> g (f a)

instance Monoidal (->) where
    f `x` g = \(a, b) -> (f a, g b)
    assocL = \((a, b), c) -> (a, (b, c))
    assocR = \(a, (b, c)) -> ((a, b), c)
    swap = \(a, b) -> (b, a)

instance Cartesian (->) where
    exl = \(a, _) -> a
    exr = \(_, b) -> b
    dup = \a -> (a, a)
    counit = \_ -> ()

instance Num a => NumCat (->) a where
    negateC = negate
    addC = uncurry (+)
    mulC = uncurry (*)
    increaseC a = (+a)

instance Floating a => FloatCat (->) a where
    expC = exp

instance Fractional a => FractCat (->) a where
    recipC = recip

-------------------------------------

instance Additive () where
    zero = ()
    () ^+ () = ()

instance {-# OVERLAPPABLE #-} Num a => Additive a where
    zero = 0
    (^+) = (+)

instance (Additive a, Additive b) => Additive (a, b) where
    zero = (zero, zero)
    (a1, b1) ^+ (a2, b2) = (a1 ^+ a2, b1 ^+ b2)


-------------------------------------

(/\) :: (Cartesian k, _) => b `k` c -> b `k` d -> b `k` (c, d)
f /\ g = (f `x` g) . dup

(\/) :: (Monoidal k, Cocartesian k, _) => a `k` c -> b `k` c -> (a, b) `k` c
f \/ g = jam . (f `x` g)

fork :: (Cartesian k, _) => (b `k` c,  b `k` d) -> b `k` (c, d)
fork (f, g) = f /\ g

unfork :: (Cartesian k, _) => b `k` (c, d) -> (b `k` c, b `k` d)
unfork h = (exl . h, exr . h)

join :: (Monoidal k, Cocartesian k, _) => (a `k` c, b `k` c) -> (a, b) `k` c
join (f, g) = f \/ g

unjoin :: (Cocartesian k, _) => (a, b) `k` c -> (a `k` c, b `k` c)
unjoin h = (h . inl, h . inr)

divide :: (Monoidal k, FractCat k a, _) => k (a, a) a
divide = mulC . (id `x` recipC)
-------------------------------------

type Allowed2 k a b = (Allowed k a, Allowed k b)
type Allowed3 k a b c = (Allowed2 k a b, Allowed k c)
type Allowed4 k a b c d = (Allowed3 k a b c, Allowed k d)
type Allowed5 k a b c d e = (Allowed4 k a b c d, Allowed k e)
type Allowed6 k a b c d e f = (Allowed5 k a b c d e, Allowed k f)
type Allowed7 k a b c d e f g = (Allowed6 k a b c d e f, Allowed k g)
type Allowed8 k a b c d e f g h = (Allowed7 k a b c d e f g, Allowed k h)
type Allowed9 k a b c d e f g h i = (Allowed8 k a b c d e f g i, Allowed k i)
