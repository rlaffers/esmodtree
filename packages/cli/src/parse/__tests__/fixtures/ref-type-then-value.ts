import { MyClass } from './exports'

type C = typeof MyClass
interface Impl extends C {}
class A implements MyClass {
  value = 1
}

export const value = new MyClass()
