<script setup>
import { computed } from 'vue'
import { useTimelineStore } from '../stores/timelineStore.js'
import { ElMessage } from 'element-plus'

const props = defineProps({
  connection: { type: Object, required: true },
  containerRef: { type: Object, required: false },
  renderKey: { type: Number }
})

const store = useTimelineStore()
const gradientId = computed(() => `grad-${props.connection.id}`)

// 判断当前连线是否被左键选中
const isSelected = computed(() => store.selectedConnectionId === props.connection.id)

function onRightClick() {
  store.removeConnection(props.connection.id)
  ElMessage.success({ message: '已删除 1 条连线', duration: 1000 })
}

function onSelectClick(evt) {
  evt.stopPropagation()
  store.selectConnection(props.connection.id)
}

// ===================================================================================
// 辅助函数 (颜色与坐标计算)
// ===================================================================================

const resolveColor = (info, effectIndex) => {
  if (!info || !info.action) return store.getColor('default')
  const { action, trackIndex } = info

  if (effectIndex !== undefined && effectIndex !== null) {
    const raw = action.physicalAnomaly || []
    if (raw.length === 0) return store.getColor('default')
    const flatList = Array.isArray(raw[0]) ? raw.flat() : raw
    const effect = flatList[effectIndex]
    if (effect && effect.type) return store.getColor(effect.type)
    return store.getColor('default')
  }

  if (action.type === 'link') return store.getColor('link')
  if (action.type === 'execution') return store.getColor('execution')
  if (action.type === 'attack') return store.getColor('physical')
  if (action.element) return store.getColor(action.element)

  if (trackIndex !== undefined && trackIndex !== null) {
    const track = store.tracks[trackIndex]
    if (track && track.id) return store.getCharacterElementColor(track.id)
  }

  return store.getColor(action.type)
}

const getDomPosition = (elementId, containerEl, isSource) => {
  const el = document.getElementById(elementId)
  if (!el || !containerEl) return null
  const rect = el.getBoundingClientRect()
  const containerRect = containerEl.getBoundingClientRect()
  const offsetX = isSource ? rect.right : rect.left
  const x = (offsetX - containerRect.left) + containerEl.scrollLeft
  const y = (rect.top - containerRect.top) + (rect.height / 2) + containerEl.scrollTop
  return { x, y }
}

const getTriggerDotPosition = (instanceId, containerEl) => {
  const actionEl = document.getElementById(`action-${instanceId}`)
  if (!actionEl) return null
  const dotEl = actionEl.querySelector('.tw-dot')
  if (!dotEl) return null
  const rect = dotEl.getBoundingClientRect()
  const containerRect = containerEl.getBoundingClientRect()
  const x = (rect.left - containerRect.left) + (rect.width / 2) + containerEl.scrollLeft
  const y = (rect.top - containerRect.top) + (rect.height / 2) + containerEl.scrollTop
  return { x, y }
}

const getTrackCenterY = (trackIndex) => {
  const rowEl = document.getElementById(`track-row-${trackIndex}`)
  if (rowEl) return rowEl.offsetTop + (rowEl.offsetHeight / 2)
  return 20 + trackIndex * 80
}

// ===================================================================================
// 核心计算
// ===================================================================================

const calculatePoint = (nodeId, effectIndex, isSource) => {
  const info = store.getActionPositionInfo(nodeId)
  if (!info) return null

  if (effectIndex !== undefined && effectIndex !== null) {
    const domId = `anomaly-${nodeId}-${effectIndex}`
    const pos = getDomPosition(domId, props.containerRef, isSource)
    if (pos) return { x: pos.x, y: pos.y }
  }

  if (!isSource && info.action.triggerWindow && info.action.triggerWindow !== 0) {
    const dotPos = getTriggerDotPosition(nodeId, props.containerRef)
    if (dotPos) return { x: dotPos.x, y: dotPos.y }
  }

  let timePoint = 0
  if (isSource) {
    timePoint = info.action.startTime + info.action.duration
  } else {
    const window = info.action.triggerWindow || 0
    timePoint = info.action.startTime - Math.abs(window)
  }

  const x = timePoint * store.timeBlockWidth
  let y = getTrackCenterY(info.trackIndex)

  if (!isSource && effectIndex == null && info.action.triggerWindow <= 0) {
    const incoming = store.getIncomingConnections(nodeId)
    const generalIncoming = incoming.filter(c => c.toEffectIndex == null)
    generalIncoming.sort((a, b) => a.id.localeCompare(b.id))
    const myIndex = generalIncoming.findIndex(c => c.id === props.connection.id)
    if (myIndex !== -1 && generalIncoming.length > 1) {
      const spread = 6
      y += (myIndex - (generalIncoming.length - 1) / 2) * spread
    }
  }

  return { x, y }
}

const pathInfo = computed(() => {
  const _trigger = props.renderKey
  const conn = props.connection

  const fromInfo = store.getActionPositionInfo(conn.from)
  const toInfo = store.getActionPositionInfo(conn.to)
  if (!fromInfo || !toInfo) return null

  const start = calculatePoint(conn.from, conn.fromEffectIndex, true)
  const end = calculatePoint(conn.to, conn.toEffectIndex, false)
  if (!start || !end) return null

  const colorStart = resolveColor(fromInfo, conn.fromEffectIndex)
  const colorEnd = resolveColor(toInfo, conn.toEffectIndex)

  const dx = Math.abs(end.x - start.x)
  const controlDist = Math.max(50, Math.min(dx * 0.6, 200))
  const d = `M ${start.x} ${start.y} C ${start.x + controlDist} ${start.y}, ${end.x - controlDist} ${end.y}, ${end.x} ${end.y}`

  return {
    d,
    startPoint: { x: start.x, y: start.y },
    endPoint: { x: end.x, y: end.y },
    colors: { start: colorStart, end: colorEnd }
  }
})
</script>

<template>
  <g v-if="pathInfo"
     class="connector-group"
     :class="{ 'is-selected': isSelected }"
     @click="onSelectClick"
     @contextmenu.prevent="onRightClick"
  >
    <defs>
      <linearGradient :id="gradientId" gradientUnits="userSpaceOnUse" :x1="pathInfo.startPoint.x" :y1="pathInfo.startPoint.y" :x2="pathInfo.endPoint.x" :y2="pathInfo.endPoint.y">
        <stop offset="0%" :stop-color="pathInfo.colors.start" stop-opacity="0.8"/>
        <stop offset="100%" :stop-color="pathInfo.colors.end" stop-opacity="1"/>
      </linearGradient>
    </defs>

    <path :d="pathInfo.d"
          fill="none"
          :stroke="pathInfo.colors.end"
          stroke-width="12"
          class="hover-zone"
    >
      <title>左键选中+Delete / 右键 删除</title>
    </path>

    <path :d="pathInfo.d"
          fill="none"
          :stroke="isSelected ? '#ffffff' : `url(#${gradientId})`"
          stroke-width="2"
          stroke-linecap="round"
          class="main-path"
    />

    <circle r="2">
      <animateMotion :path="pathInfo.d" dur="1.5s" repeatCount="indefinite" calcMode="spline" keyTimes="0;1" keySplines="0.4 0 0.2 1"/>
      <animate attributeName="fill" :values="`${pathInfo.colors.start};${pathInfo.colors.end}`" dur="1.5s" repeatCount="indefinite" calcMode="spline" keyTimes="0;1" keySplines="0.4 0 0.2 1"/>
    </circle>
  </g>
</template>

<style scoped>
.connector-group { cursor: pointer; }
.connector-group.is-selected .main-path { stroke-width: 3; filter: drop-shadow(0 0 4px rgba(255, 255, 255, 0.9)); z-index: 999; }
.hover-zone { pointer-events: stroke; transition: stroke-opacity 0.2s; stroke-opacity: 0; }
.connector-group:hover .hover-zone { stroke-opacity: 0.4; }
.main-path { pointer-events: none; filter: drop-shadow(0 0 2px rgba(0, 0, 0, 0.5)); stroke-dasharray: 10, 5; animation: dash-flow 30s linear infinite; transition: stroke 0.2s; }
@keyframes dash-flow {  to { stroke-dashoffset: -1000; } }
</style>