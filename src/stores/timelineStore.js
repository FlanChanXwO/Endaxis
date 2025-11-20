import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

const uid = () => Math.random().toString(36).substring(2, 9)

export const useTimelineStore = defineStore('timeline', () => {

    const characterRoster = ref([])
    const isLoading = ref(true)
    const iconDatabase = ref({})

    // 初始轨道
    const tracks = ref([
        { id: null, actions: [] },
        { id: null, actions: [] },
        { id: null, actions: [] },
        { id: null, actions: [] },
    ])

    const activeTrackId = ref(null)
    const linkState = ref({ windows: {} })

    // 全局拖拽偏移量
    const globalDragOffset = ref(0)
    function setDragOffset(offset) {
        globalDragOffset.value = offset
    }

    const connections = ref([])
    const isLinking = ref(false)
    const linkingSourceId = ref(null)
    const linkingEffectIndex = ref(null)

    // 新增：技能库状态
    const selectedLibrarySkillId = ref(null)
    const skillOverrides = ref({})

    // === 1. 项目导出功能 ===
    function exportProject() {
        const projectData = {
            version: '1.0.0',
            timestamp: Date.now(),
            tracks: tracks.value,
            connections: connections.value,
            // 别忘了保存用户修改过的技能数值
            skillOverrides: skillOverrides.value
        }

        const jsonString = JSON.stringify(projectData, null, 2)
        const blob = new Blob([jsonString], { type: 'application/json' })
        const link = document.createElement('a')
        link.href = URL.createObjectURL(blob)
        // 文件名带上时间戳
        const dateStr = new Date().toISOString().slice(0,10)
        link.download = `endaxis_project_${dateStr}.json`
        link.click()
        URL.revokeObjectURL(link.href)
    }

    // === 2. 项目导入功能 ===
    async function importProject(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader()
            reader.onload = (e) => {
                try {
                    const data = JSON.parse(e.target.result)

                    // 简单的校验
                    if (!data.tracks || !Array.isArray(data.tracks)) {
                        throw new Error("文件格式错误：缺少轨道数据")
                    }

                    // 恢复状态
                    tracks.value = data.tracks
                    connections.value = data.connections || []
                    skillOverrides.value = data.skillOverrides || {}

                    // 重置选中状态
                    selectedActionId.value = null
                    selectedLibrarySkillId.value = null
                    isLinking.value = false

                    resolve(true)
                } catch (err) {
                    console.error("导入失败", err)
                    reject(err)
                }
            }
            reader.readAsText(file)
        })
    }

    function startLinking(effectIndex = null) {
        if (selectedActionId.value) {
            isLinking.value = true
            linkingSourceId.value = selectedActionId.value
            linkingEffectIndex.value = effectIndex
        }
    }

    function confirmLinking(targetId) {
        if (!isLinking.value || !linkingSourceId.value) {
            isLinking.value = false;
            linkingSourceId.value = null;
            linkingEffectIndex.value = null;
            return;
        }

        if (linkingSourceId.value === targetId) {
            alert("不能连接自己！");
        } else {
            const exists = connections.value.some(c =>
                c.from === linkingSourceId.value &&
                c.to === targetId &&
                c.fromEffectIndex === linkingEffectIndex.value
            )

            if (!exists) {
                connections.value.push({
                    id: `conn_${uid()}`,
                    from: linkingSourceId.value,
                    to: targetId,
                    fromEffectIndex: linkingEffectIndex.value
                })
            } else {
                alert("该连接已存在！");
            }
        }
        isLinking.value = false
        linkingSourceId.value = null
        linkingEffectIndex.value = null
    }

    function cancelLinking() {
        isLinking.value = false
        linkingSourceId.value = null
        linkingEffectIndex.value = null
    }

    function removeConnection(connId) {
        connections.value = connections.value.filter(c => c.id !== connId)
    }

    const teamTracksInfo = computed(() => {
        return tracks.value.map(track => {
            const charInfo = characterRoster.value.find(c => c.id === track.id)
            return { ...track, ...(charInfo || { name: '未知', avatar: '', rarity: 0 }) }
        })
    })

    const activeSkillLibrary = computed(() => {
        const activeChar = characterRoster.value.find(c => c.id === activeTrackId.value)
        if (!activeChar) return []

        const getAnomalies = (list) => list || []
        const getAllowed = (list) => list || []

        const createBaseSkill = (suffix, type, name, props) => {
            const id = `${activeChar.id}_${suffix}`
            const override = skillOverrides.value[id] || {}

            const base = {
                id: id,
                type: type,
                name: name,
                duration: activeChar[`${suffix}_duration`],
                cooldown: activeChar[`${suffix}_cooldown`],
                spCost: activeChar[`${suffix}_spCost`],
                spGain: activeChar[`${suffix}_spGain`],
                allowedTypes: getAllowed(activeChar[`${suffix}_allowed_types`]),
                physicalAnomaly: getAnomalies(activeChar[`${suffix}_anomalies`])
            }
            return { ...base, ...override }
        }

        return [
            createBaseSkill('attack', 'attack', '重击'),
            createBaseSkill('skill', 'skill', '战技'),
            createBaseSkill('link', 'link', '连携'),
            createBaseSkill('ultimate', 'ultimate', '终结技')
        ]
    })

    const cloneSkill = (skill) => {
        const clonedAnomalies = skill.physicalAnomaly
            ? JSON.parse(JSON.stringify(skill.physicalAnomaly))
            : [];

        return {
            ...skill,
            instanceId: `inst_${uid()}`,
            physicalAnomaly: clonedAnomalies
        }
    }

    function selectLibrarySkill(skillId) {
        selectedActionId.value = null
        if (selectedLibrarySkillId.value === skillId) {
            selectedLibrarySkillId.value = null
        } else {
            selectedLibrarySkillId.value = skillId
        }
    }

    function updateLibrarySkill(skillId, props) {
        if (!skillOverrides.value[skillId]) {
            skillOverrides.value[skillId] = {}
        }
        Object.assign(skillOverrides.value[skillId], props)
    }

    function updateAction(instanceId, newProperties) {
        for (const track of tracks.value) {
            const action = track.actions.find(a => a.instanceId === instanceId)
            if (action) {
                Object.assign(action, newProperties)
                return
            }
        }
    }

    const selectedActionId = ref(null)

    function selectAction(instanceId) {
        selectedLibrarySkillId.value = null
        selectedActionId.value = instanceId === selectedActionId.value ? null : instanceId
    }

    function selectTrack(trackId) {
        activeTrackId.value = trackId
        selectedActionId.value = null
        selectedLibrarySkillId.value = null
        cancelLinking()
    }

    function removeAction(instanceId) {
        if (!instanceId) return
        for (const track of tracks.value) {
            const index = track.actions.findIndex(a => a.instanceId === instanceId)
            if (index !== -1) {
                track.actions.splice(index, 1)
                break
            }
        }
        connections.value = connections.value.filter(c => c.from !== instanceId && c.to !== instanceId)
        if (selectedActionId.value === instanceId) {
            selectedActionId.value = null
        }
    }

    async function fetchGameData() {
        try {
            isLoading.value = true
            const response = await fetch('/gamedata.json')
            if (!response.ok) throw new Error('无法加载 gamedata.json')
            const data = await response.json()
            const sortedRoster = data.characterRoster.sort((a, b) => {
                return (b.rarity || 0) - (a.rarity || 0);
            });
            characterRoster.value = sortedRoster
            iconDatabase.value = data.ICON_DATABASE
        } catch (error) {
            console.error("加载游戏数据失败:", error)
        } finally {
            isLoading.value = false
        }
    }

    function changeTrackOperator(trackIndex, oldOperatorId, newOperatorId) {
        const track = tracks.value[trackIndex];
        if (track) {
            const isAlreadyInUse = tracks.value.some((t, index) => index !== trackIndex && t.id === newOperatorId);
            if (isAlreadyInUse) {
                alert('该干员已在另一条轨道上！');
                return;
            }
            track.id = newOperatorId;
            track.actions = [];
            if (activeTrackId.value === oldOperatorId) {
                activeTrackId.value = newOperatorId;
            }
        }
    }

    return {
        isLoading,
        fetchGameData,
        characterRoster,
        iconDatabase,
        teamTracksInfo,
        activeTrackId,
        selectTrack,
        activeSkillLibrary,
        tracks,
        cloneSkill,
        connections,
        removeConnection,
        isLinking,
        linkingSourceId,
        startLinking,
        confirmLinking,
        cancelLinking,
        updateAction,
        selectedActionId,
        selectAction,
        linkState,
        changeTrackOperator,
        globalDragOffset,
        setDragOffset,
        selectedLibrarySkillId,
        selectLibrarySkill,
        updateLibrarySkill,
        removeAction,
        exportProject,
        importProject
    }
})