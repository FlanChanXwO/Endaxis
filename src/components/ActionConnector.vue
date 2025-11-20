<script setup>
import { computed } from 'vue'

const props = defineProps({
  connection: { type: Object, required: true },
  containerRef: { type: Object, required: true }, // 注意：这里接收的是 DOM 元素
  renderKey: { type: Number }
})

const TIME_BLOCK_WIDTH = 50

const pathData = computed(() => {
  // 依赖 renderKey 强制更新，确保滚动时重新计算
  const key = props.renderKey;

  if (!props.containerRef) return ''

  const fromEl = document.getElementById(`action-${props.connection.from}`)
  const toEl = document.getElementById(`action-${props.connection.to}`)

  let actualFromEl = fromEl;
  // 处理从 Buff 图标发起的连线
  if (props.connection.fromEffectIndex !== undefined && props.connection.fromEffectIndex !== null) {
    const iconEl = document.getElementById(`anomaly-${props.connection.from}-${props.connection.fromEffectIndex}`);
    if (iconEl) {
      actualFromEl = iconEl;
    }
  }

  if (!fromEl || !toEl) return ''

  // 1. 获取矩形坐标 (Viewport 坐标)
  const containerRect = props.containerRef.getBoundingClientRect()
  const fromRect = actualFromEl.getBoundingClientRect()
  const toRect = toEl.getBoundingClientRect()

  // 2. 获取滚动偏移量 (关键修复！)
  const scrollLeft = props.containerRef.scrollLeft || 0
  const scrollTop = props.containerRef.scrollTop || 0

  // 3. 计算绝对坐标 = (元素视口坐标 - 容器视口坐标) + 容器滚动距离
  const x1 = (fromRect.right - containerRect.left) + scrollLeft
  const y1 = (fromRect.top - containerRect.top) + scrollTop + (fromRect.height / 2)

  const x2 = (toRect.left - containerRect.left) + scrollLeft
  const y2 = (toRect.top - containerRect.top) + scrollTop + (toRect.height / 2)

  // 4. 贝塞尔曲线逻辑
  const fixedWidth = 0.5 * TIME_BLOCK_WIDTH
  const x_vertical = x2 - fixedWidth

  return `M ${x1} ${y1} L ${x_vertical} ${y1} L ${x_vertical} ${y2} L ${x2} ${y2}`
})
</script>

<template>
  <g>
    <path
        :d="pathData"
        fill="none"
        stroke="#ffd700"
        stroke-width="2"
    />
  </g>
</template>