class HighlightFactory
  constructor: () ->
    return {
      createWrapper: () ->
        span = document.createElement 'span'
        span.style.background = 'rgba(255, 0, 0, 0.2)'
        return span
    }

class HighlighterService
  IGNORE_TAGS = ['SCRIPT', 'STYLE', 'SELECT', 'OPTION', 'OBJECT', 'APPLET',
    'VIDEO', 'AUDIO', 'CANVAS', 'EMBED', 'PARAM', 'METER', 'PROGRESS']

  constructor: (@HighlightFactory) ->

  refineRangeBoundaries: (range) =>
    startContainer = range.startContainer
    endContainer = range.endContainer
    ancestor = range.commonAncestorContainer
    goDeeper = true

    switch
      when range.endOffset == 0
        while !endContainer.previousSibling and endContainer.parentNode != ancestor
          endContainer = endContainer.parentNode
        endContainer = endContainer.previousSibling;

      when endContainer.nodeType == 3
        if range.endOffset < endContainer.nodeValue.length
          endContainer.splitText range.endOffset

      when range.endOffset > 0
        endContainer = endContainer.childNodes.item(range.endOffset - 1);

    switch
      when startContainer.nodeType == 3
        if range.startOffset == startContainer.nodeValue.length
          goDeeper = false
        else if range.startOffset > 0
          startContainer = startContainer.splitText(range.startOffset)
          endContainer = startContainer unless endContainer != startContainer.previousSibling

      when range.startOffset < startContainer.childNodes.length
        startContainer = startContainer.childNodes.item(range.startOffset)

      else
        startContainer = startContainer.nextSibling

    startContainer: startContainer,
    endContainer: endContainer,
    goDeeper: goDeeper

  highlightRange: (el, range, wrapper) =>
    result = @refineRangeBoundaries(range)
    startContainer = result.startContainer
    endContainer = result.endContainer
    goDeeper = result.goDeeper
    done = false
    node = startContainer
    highlights = []

    loop
      if goDeeper and node.nodeType == 3
        if node.parentNode.tagName not in IGNORE_TAGS and node.nodeValue.trim() != ''
          wrapperClone = wrapper.cloneNode true
          # todo: set comment ID for the wrapper or something like that
          nodeParent = node.parentNode

          if (el != nodeParent and el.contains nodeParent) or nodeParent == el
            if node.parentNode
              node.parentNode.insertBefore wrapperClone, node
            wrapperClone.appendChild(node)
            highlight = wrapperClone
            highlights.push highlight

        goDeeper = false

      if node == endContainer and !(endContainer.hasChildNodes() and goDeeper)
        done = true

      if node.tagName and node.tagName in IGNORE_TAGS
        if endContainer.parentNode is node
          done = true
        goDeeper = false

      node = switch
        when goDeeper and node.hasChildNodes then node.firstChild
        when node.nextSibling
          goDeeper = true
          node.nextSibling
        else
          goDeeper = false
          node.parentNode

      break if done

    return highlights

  highlight: (el, range) =>
    wrapper = @HighlightFactory.createWrapper()
    console.log @highlightRange el, range, wrapper

class HighlighterDirective
  constructor: (@HighlighterService, @$element) ->
    @el = @$element[0]
    @el.addEventListener 'mouseup', @handleHighlight

  getSelection: =>
    return (@el.ownerDocument || @el).defaultView.getSelection()

  handleHighlight: =>
    selection = @getSelection()
    return unless selection.rangeCount > 0

    range = selection.getRangeAt(0)
    return if range.collapsed

    @HighlighterService.highlight(@el, range)

app = angular.module 'ng-highlighter', []

app.factory 'HighlightFactory', HighlightFactory

app.service 'HighlighterService', HighlighterService

app.directive 'highlighter', () ->
  restrict: 'A',
  controller: HighlighterDirective