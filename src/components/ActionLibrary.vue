<script setup>
import draggable from 'vuedraggable'
import { computed, ref, watch } from 'vue'
import { useTimelineStore } from '../stores/timelineStore.js'

const store = useTimelineStore()

const activeCharacterName = computed(() => {
  const activeChar = store.characterRoster.find(c => c.id === store.activeTrackId)
  return activeChar ? activeChar.name : '技能库'
})

const localSkills = ref([])

function onSkillClick(skillId) {
  store.selectLibrarySkill(skillId)
}

watch(
    () => store.activeSkillLibrary,
    (newVal) => {
      if (newVal && newVal.length > 0) {
        localSkills.value = JSON.parse(JSON.stringify(newVal))
      } else {
        localSkills.value = []
      }
    },
    { immediate: true, deep: true }
)

function onDragStart(evt) {
  const rect = evt.item.getBoundingClientRect();
  if (evt.originalEvent) {
    const offsetX = evt.originalEvent.clientX - rect.left;
    store.setDragOffset(offsetX);
  }
  document.body.classList.add('is-dragging-from-library');
}

function onDragEnd() {
  document.body.classList.remove('is-dragging-from-library');
}
</script>

<template>
  <div class="library-container">
    <h3>{{ activeCharacterName }} 的技能</h3>
    <div class="hint-text">点击技能可修改基础数值</div>

    <draggable
        class="skill-list"
        v-model="localSkills"
        item-key="id"
        :group="{ name: 'skills', pull: 'clone', put: false }"
        :sort="false"
        :clone="store.cloneSkill"
        ghost-class="lib-ghost-item"
        drag-class="blue-drag-proxy"
        :forceFallback="true"
        :fallbackOnBody="true"
        @start="onDragStart"
        @end="onDragEnd"
    >
      <template #item="{ element }">
        <div
            class="skill-item"
            :class="{ 'is-selected': store.selectedLibrarySkillId === element.id }"
            :style="{ '--duration': element.duration }"
            @click="onSkillClick(element.id)"
        >
          {{ element.name }}
        </div>
      </template>
    </draggable>
  </div>
</template>

<style scoped>
.library-container {
  padding: 10px;
  display: flex;
  flex-direction: column;
  flex-grow: 1;
}

.skill-list {
  display: flex;
  flex-direction: row;
  flex-wrap: wrap;
  gap: 10px;
}

.hint-text {
  font-size: 12px;
  color: #888;
  margin-bottom: 10px;
}

.skill-item {
  transition: all 0.2s;
  transform: translate(0, 0);
}

.skill-item.is-selected {
  border-color: #ffd700;
  color: #ffd700;
  background-color: #4a4a3a;
  box-shadow: 0 0 5px rgba(255, 215, 0, 0.3);
}
</style>