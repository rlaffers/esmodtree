export function MyFunction() {
  return 'hello'
}

export class MyClass {
  value = 42
}

export const MY_CONST = 'constant'

export let myLet = true

export type MyType = { name: string }

export interface MyInterface {
  id: number
}

export enum MyEnum {
  A,
  B,
}

function notExported() {
  return 'private'
}

const alsoNotExported = 123

export { notExported as AliasedExport }
