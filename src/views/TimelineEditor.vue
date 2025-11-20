<script setup>
import TimelineGrid from '../components/TimelineGrid.vue'
import ActionLibrary from '../components/ActionLibrary.vue'
import PropertiesPanel from '../components/PropertiesPanel.vue'
import { onMounted, ref } from 'vue'
import { useTimelineStore } from '../stores/timelineStore.js'

const store = useTimelineStore()
const fileInputRef = ref(null)

onMounted(() => {
  store.fetchGameData()
})

// 触发隐藏的文件输入框点击
function triggerImport() {
  if (fileInputRef.value) {
    fileInputRef.value.click()
  }
}

// 处理文件选择
async function onFileSelected(event) {
  const file = event.target.files[0]
  if (!file) return

  try {
    await store.importProject(file)
    // 简单的成功提示，实际项目中可以用 ElMessage
    alert('项目加载成功！')
  } catch (e) {
    alert('加载失败：' + e.message)
  } finally {
    // 清空 input，防止选择同一个文件不触发 change
    event.target.value = ''
  }
}
</script>

<template>
  <div v-if="store.isLoading" class="loading-screen">
    正在加载游戏数据...
  </div>

  <div v-if="!store.isLoading" class="app-layout">

    <aside class="action-library">
      <ActionLibrary />
    </aside>

    <main class="timeline-main">
      <header class="timeline-header" @click="store.selectTrack(null)">
        <span class="header-title">控制区</span>

        <div class="header-controls">
          <button class="control-btn save-btn" @click="store.exportProject">
            💾 保存项目
          </button>
          <button class="control-btn load-btn" @click="triggerImport">
            📂 读取项目
          </button>
          <input
              type="file"
              ref="fileInputRef"
              style="display: none"
              accept=".json"
              @change="onFileSelected"
          />
        </div>
      </header>

      <div class="timeline-grid-container">
        <TimelineGrid />
      </div>
    </main>

    <aside class="properties-sidebar">
      <PropertiesPanel />
    </aside>

  </div>
</template>

<style scoped>
.loading-screen {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100vw;
  height: 100vh;
  font-size: 20px;
  color: #f0f0f0;
}

/* 使用 Grid 实现三栏布局 */
.app-layout {
  display: grid;
  grid-template-columns: 200px 1fr 250px;
  grid-template-rows: 100vh;
  height: 100vh;
  overflow: hidden;
  background-color: #2c2c2c;
}

.action-library {
  background-color: #333;
  border-right: 1px solid #444;
  display: flex;
  flex-direction: column;
  overflow-y: auto;
  overflow-x: hidden;
  position: relative;
  z-index: 10;
}

.timeline-main {
  display: grid;
  grid-template-rows: 50px 1fr;
  overflow: hidden;
  background-color: #282828;
  z-index: 1;
  border-right: 1px solid #444;
}

.timeline-header {
  height: 50px;
  border-bottom: 1px solid #444;
  display: flex;
  align-items: center;
  justify-content: space-between; /* 让标题和按钮两端对齐 */
  padding: 0 20px;
  background-color: #3a3a3a;
  cursor: default;
  user-select: none;
}

.header-title {
  font-weight: bold;
  color: #aaa;
}

.header-controls {
  display: flex;
  gap: 10px;
}

.control-btn {
  padding: 5px 12px;
  border: 1px solid #555;
  background-color: #444;
  color: #f0f0f0;
  border-radius: 4px;
  cursor: pointer;
  font-size: 12px;
  display: flex;
  align-items: center;
  gap: 5px;
  transition: all 0.2s;
}

.control-btn:hover {
  background-color: #555;
  border-color: #777;
}

.control-btn:active {
  transform: translateY(1px);
}

/* 区分一下保存和读取的微小样式 */
.save-btn:hover {
  border-color: #4CAF50;
  color: #4CAF50;
}

.load-btn:hover {
  border-color: #4a90e2;
  color: #4a90e2;
}

.timeline-grid-container {
  padding: 0;
  height: 100%;
  overflow: hidden;
}

.properties-sidebar {
  background-color: #333;
  overflow: hidden;
  z-index: 10;
}
</style>