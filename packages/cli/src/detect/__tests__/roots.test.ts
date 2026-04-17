import { describe, expect, it } from 'vitest'
import { detectRootMarkers } from '../roots'
import { ProjectType } from '../project'

describe('detectRootMarkers', () => {
  it('flags pages router files as [page] in Next.js projects', () => {
    const markers = detectRootMarkers(ProjectType.NextJs, [
      'pages/index.tsx',
      'pages/about.tsx',
      'pages/api/hello.ts',
    ])

    expect(markers.get('pages/index.tsx')).toEqual(['page'])
    expect(markers.get('pages/about.tsx')).toEqual(['page'])
    expect(markers.get('pages/api/hello.ts')).toEqual(['page'])
  })

  it('does not flag _app.tsx and _document.tsx as pages', () => {
    const markers = detectRootMarkers(ProjectType.NextJs, [
      'pages/_app.tsx',
      'pages/_document.tsx',
      'pages/index.tsx',
    ])

    expect(markers.has('pages/_app.tsx')).toBe(false)
    expect(markers.has('pages/_document.tsx')).toBe(false)
    expect(markers.get('pages/index.tsx')).toEqual(['page'])
  })

  it('flags app router page.tsx as [page] and layout.tsx as [layout]', () => {
    const markers = detectRootMarkers(ProjectType.NextJs, [
      'app/page.tsx',
      'app/layout.tsx',
      'app/dashboard/page.tsx',
      'app/dashboard/layout.tsx',
    ])

    expect(markers.get('app/page.tsx')).toEqual(['page'])
    expect(markers.get('app/layout.tsx')).toEqual(['layout'])
    expect(markers.get('app/dashboard/page.tsx')).toEqual(['page'])
    expect(markers.get('app/dashboard/layout.tsx')).toEqual(['layout'])
  })

  it('flags generic TS entry points as [entry]', () => {
    const markers = detectRootMarkers(ProjectType.Generic, [
      'src/index.ts',
      'src/main.ts',
      'src/utils/helpers.ts',
    ])

    expect(markers.get('src/index.ts')).toEqual(['entry'])
    expect(markers.get('src/main.ts')).toEqual(['entry'])
    expect(markers.has('src/utils/helpers.ts')).toBe(false)
  })
})
